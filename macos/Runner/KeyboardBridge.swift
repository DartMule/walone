import Cocoa
import Carbon
import FlutterMacOS

/// Управление из Flutter; события и звук остаются на главном нативном потоке.
final class KeyboardBridge: NSObject, FlutterStreamHandler {
    private let channel: FlutterMethodChannel
    let experiment = SensorExperiment()
    private var sensorDialog = false
    private let audio: KeyboardAudio
    private let lifecycleChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var outputMonitor: AudioOutputMonitor?
    private var masterVolume: Float = 0.7
    private var allowed = true
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var active = false
    private var enabled = false
    private var volume: Float = 0.35
    private var receivedKeys: Int64 = 0
    private var statisticsActive = false
    private var statisticsKeys: Int64 = 0
    private var errorMessage: String?
    private var observers: [NSObjectProtocol] = []

    init(controller: FlutterViewController, audio: KeyboardAudio? = nil) {
        let asset = controller.lookupKey(forAsset: "assets/keyboards/brown/key0.wav")
        self.audio = audio ?? KeyboardAudio(resourcesURL: Bundle.main.bundleURL.appendingPathComponent(asset).deletingLastPathComponent().deletingLastPathComponent())
        channel = FlutterMethodChannel(name: "dev.soyjanks.walone/keyboard", binaryMessenger: controller.engine.binaryMessenger)
        lifecycleChannel = FlutterEventChannel(name: "dev.soyjanks.walone/lifecycle", binaryMessenger: controller.engine.binaryMessenger)
        super.init()
        lifecycleChannel.setStreamHandler(self)
        outputMonitor = AudioOutputMonitor { [weak self] removed in
            guard let self, removed else { return }
            self.allowed = false
            self.audio.stop()
            self.eventSink?(["reason": "output"])
        }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "disposed", message: "Модуль остановлен", details: nil)); return }
            self.handle(call, result: result)
        }
        // Сон экрана может предшествовать системному сну или происходить отдельно.
        for notification in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: notification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.experiment.suspend()
                self?.allowed = false
                self?.eventSink?(["reason": "sleep"])
                self?.audio.stop()
                self?.removeTap()
            })
        }
    }

    deinit {
        shutdown()
        lifecycleChannel.setStreamHandler(nil)
        channel.setMethodCallHandler(nil)
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "initialize":
                try audio.selectPack(.brown)
                active = true
                updateTap()
                if timer == nil {
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateTap() }
                }
                result(status())
            case "sensorStatus":
                result(experiment.status())
            case "sensorConfigure":
                guard let arguments = call.arguments as? [String: Any] else { throw CocoaError(.coderReadCorrupt) }
                try experiment.configure(arguments)
                result(experiment.status())
            case "sensorReset", "sensorLoadCalibration", "sensorRemoveCalibration", "sensorExport":
                sensorDialog = true
                audio.stop()
                defer { sensorDialog = false }
                switch call.method {
                case "sensorReset": experiment.reset()
                case "sensorLoadCalibration": try experiment.loadCalibration()
                case "sensorRemoveCalibration": experiment.removeCalibration()
                default: try experiment.exportSummary(soundEnabled: enabled, paused: !allowed)
                }
                result(experiment.status())
            case "status":
                updateTap()
                result(status())
            case "statistics":
                guard let enabled = call.arguments as? Bool else { throw CocoaError(.coderReadCorrupt) }
                statisticsActive = enabled
                result(statisticsKeys)
            case "configure":
                guard let arguments = call.arguments as? [String: Any],
                      let id = arguments["pack"] as? String, let pack = KeyboardSoundPack(rawValue: id),
                      let enabled = arguments["enabled"] as? Bool,
                      let volume = arguments["volume"] as? Double, volume.isFinite, (0...1).contains(volume) else {
                    result(FlutterError(code: "arguments", message: "Некорректные настройки клавиатуры", details: nil)); return
                }
                try audio.selectPack(pack)
                self.volume = Float(volume)
                self.enabled = enabled
                errorMessage = nil
                if enabled { audio.prepare() }
                else { audio.stop() }
                result(nil)
            case "environment":
                guard let arguments = call.arguments as? [String: Any],
                      let volume = arguments["masterVolume"] as? Double, volume.isFinite, (0...1).contains(volume),
                      let allowed = arguments["allowed"] as? Bool else {
                    result(FlutterError(code: "arguments", message: "Некорректная общая громкость", details: nil)); return
                }
                masterVolume = Float(volume)
                self.allowed = allowed
                if !allowed { audio.stop() }
                result(nil)
            case "preview":
                if allowed { try audio.play(group: 0, volume: volume * masterVolume) }
                errorMessage = nil
                result(nil)
            case "requestPermission":
                if !CGPreflightListenEventAccess(), !CGRequestListenEventAccess(),
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                    NSWorkspace.shared.open(url)
                }
                updateTap()
                result(nil)
            case "dispose":
                shutdown()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        } catch {
            errorMessage = error.localizedDescription
            let isSensor = call.method.hasPrefix("sensor")
            result(FlutterError(code: isSensor ? "sensor" : "audio",
                message: "\(isSensor ? "Ошибка эксперимента" : "Не удалось воспроизвести звук"): \(error.localizedDescription)", details: nil))
        }
    }

    private func status() -> [String: Any] {
        ["hasPermission": CGPreflightListenEventAccess(),
         "listening": tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false,
         "secureInput": IsSecureEventInputEnabled(),
         "enabled": enabled,
         "receivedKeys": receivedKeys,
         "error": errorMessage as Any? ?? NSNull()]
    }

    private func updateTap() {
        guard active else { return }
        guard CGPreflightListenEventAccess(), !IsSecureEventInputEnabled() else {
            // Прослушивание доступно без разрешения на глобальные нажатия.
            if tap != nil {
                removeTap()
                audio.stop()
            }
            return
        }
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let bridge = Unmanaged<KeyboardBridge>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = bridge.tap, CGPreflightListenEventAccess(), !IsSecureEventInputEnabled() {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                } else if type == .keyDown, !IsSecureEventInputEnabled(), CGPreflightListenEventAccess(),
                          event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    bridge.receivedKeys += 1
                    if bridge.statisticsActive && bridge.allowed { bridge.statisticsKeys += 1 }
                    let code = event.getIntegerValueField(.keyboardEventKeycode)
                    bridge.experiment.key(time: Double(event.timestamp) / 1e9,
                        canPlay: { [weak bridge] in
                            guard let bridge else { return false }
                            return bridge.enabled && bridge.allowed && !bridge.sensorDialog
                        }, play: { [weak bridge] gain in bridge?.playKey(code: code, gain: gain) })
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            errorMessage = "Не удалось подключить нажатия. Проверьте «Мониторинг ввода» и перезапустите Walone."
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func playKey(code: Int64, gain: Float = 1) {
        guard enabled && allowed && !sensorDialog else { return }
        let group = code == 49 ? 1 : (code == 36 || code == 76 ? 2 : (code == 51 || code == 117 ? 3 : 0))
        do {
            try audio.play(group: group, volume: volume * masterVolume * gain)
            errorMessage = nil
        } catch {
            // Временная ошибка выхода не отменяет выбор пользователя; следующее нажатие повторит запуск.
            audio.stop()
            errorMessage = "Ошибка аудио: \(error.localizedDescription)"
        }
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func shutdown() {
        experiment.suspend()
        active = false
        statisticsActive = false
        timer?.invalidate()
        timer = nil
        enabled = false
        removeTap()
        audio.stop()
    }
}
