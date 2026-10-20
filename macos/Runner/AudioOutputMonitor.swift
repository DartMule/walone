import Foundation
import CoreAudio

/// Observe default-output and headphone-jack changes on the main queue.
final class AudioOutputMonitor {
    struct Output: Equatable {
        var id: AudioDeviceID
        var source: UInt32
        var privateListening: Bool
        var connected: Bool
    }
    private var previous = AudioOutputMonitor.current()
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let onChange: (Bool) -> Void
    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        observe()
    }
    static func shouldPause(previous: Output, current: Output, previousStillConnected: Bool) -> Bool {
        // AirPods могут ещё считаться подключёнными уже после перехода на динамики.
        previous.privateListening && (!previousStillConnected ||
            !current.privateListening)
    }
    private func changed() {
        let current = Self.current()
        guard current != previous else { return }
        let removed = Self.shouldPause(previous: previous, current: current, previousStillConnected: Self.isConnected(previous.id))
        previous = current
        removeListeners(); observe()
        onChange(removed)
    }
    private func observe() {
        listen(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
        listen(previous.id, kAudioDevicePropertyDataSource, scope: kAudioDevicePropertyScopeOutput)
        listen(previous.id, kAudioDevicePropertyJackIsConnected, scope: kAudioDevicePropertyScopeOutput)
        listen(previous.id, kAudioDevicePropertyDeviceIsAlive)
    }
    private func listen(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(id, &address) else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.changed() }
        if AudioObjectAddPropertyListenerBlock(id, &address, .main, block) == noErr { listeners.append((id, address, block)) }
    }
    private func removeListeners() {
        for (id, var address, block) in listeners { AudioObjectRemovePropertyListenerBlock(id, &address, .main, block) }
        listeners.removeAll()
    }
    private static func read(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, fallback: UInt32) -> UInt32 {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var result = fallback; var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &result) == noErr else { return fallback }
        return result
    }
    private static func isConnected(_ id: AudioDeviceID) -> Bool {
        read(id, kAudioDevicePropertyDeviceIsAlive, fallback: UInt32(0)) != 0 &&
        read(id, kAudioDevicePropertyJackIsConnected, scope: kAudioDevicePropertyScopeOutput, fallback: UInt32(1)) != 0
    }
    private static func current() -> Output {
        let id: AudioDeviceID = read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, fallback: AudioDeviceID(0))
        let source: UInt32 = read(id, kAudioDevicePropertyDataSource, scope: kAudioDevicePropertyScopeOutput, fallback: UInt32(0))
        let transport: UInt32 = read(id, kAudioDevicePropertyTransportType, fallback: UInt32(0))
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        var headphones = false
        if AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 {
            var streams = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.size)
            let status = streams.withUnsafeMutableBytes { AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0.baseAddress!) }
            if status == noErr {
                headphones = streams.contains { read($0, kAudioStreamPropertyTerminalType, fallback: UInt32(0)) == kAudioStreamTerminalTypeHeadphones }
            }
        }
        let personal = headphones || source == 0x6864706e || transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE || transport == kAudioDeviceTransportTypeUSB
        return Output(id: id, source: source, privateListening: personal, connected: isConnected(id))
    }
    deinit { removeListeners() }
}
