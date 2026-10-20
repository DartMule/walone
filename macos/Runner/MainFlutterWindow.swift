import Cocoa
import FlutterMacOS
import ServiceManagement

// Flutter 3.47.4 включает BGRA10_XR (8 байт/пиксель) на macOS автоматически.
// Walone рисует sRGB; используем BGRA8, сохраняя Impeller и нативное разрешение.
// Это внутренний selector FlutterDartProject: проверять при обновлении Flutter.
class WaloneDartProject: FlutterDartProject {
  @objc var enableWideGamut: Bool {
    Bundle.main.object(forInfoDictionaryKey: "WaloneEnableWideGamut") as? Bool ?? false
  }
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    desktopBridge?.hide()
    return false
  }

  deinit {
    if let observer = appearanceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
  }

  private var appearanceObserver: NSObjectProtocol?
  private var keyboardBridge: KeyboardBridge?
  private(set) var desktopBridge: DesktopBridge?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController(project: WaloneDartProject())
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    minSize = NSSize(width: 560, height: 680)
    setContentSize(NSSize(width: 920, height: 820))
    keyboardBridge = KeyboardBridge(controller: flutterViewController)
    desktopBridge = DesktopBridge(window: self, controller: flutterViewController)

    let appearance = FlutterMethodChannel(
      name: "dev.soyjanks.walone/appearance",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    appearance.setMethodCallHandler { [weak self] call, result in
      guard call.method == "accessibility" else {
        result(FlutterMethodNotImplemented)
        return
      }
      var settings: [String: Any] = [
        "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
        "increaseContrast": NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
        "windowVisible": self?.isVisible == true
      ]
      if let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
        settings["accentColor"] = Int64(0xFF000000)
          | (Int64((accent.redComponent * 255).rounded()) << 16)
          | (Int64((accent.greenComponent * 255).rounded()) << 8)
          | Int64((accent.blueComponent * 255).rounded())
      }
      // Недокументированный ключ: отсутствие и незнакомые значения означают
      // недоступность синхронизации, а не нулевую степень тонирования.
      CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
      if let raw = CFPreferencesCopyValue(
        "NSGlassTintAmount" as CFString, kCFPreferencesAnyApplication,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost
      ), CFGetTypeID(raw) == CFNumberGetTypeID(),
         let number = raw as? NSNumber {
        let tint = number.doubleValue
        if tint.isFinite && (0...1).contains(tint) {
          settings["glassTint"] = tint
        }
      }
      result(settings)
    }
    appearanceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil, queue: .main
    ) { _ in
      appearance.invokeMethod("changed", arguments: nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    delegate = self
  }
}

// Системное меню и автозапуск используют то же состояние, что и Flutter-интерфейс.
class DesktopBridge: NSObject {
  private weak var window: NSWindow?
  private let channel: FlutterMethodChannel
  private let appearanceChannel: FlutterMethodChannel
  private var item: NSStatusItem?
  private var timerTitle = ""
  private var timerRunning = false
  private var playerTitle = ""
  private var playerPlaying = false
  private var playerAvailable = false
  private var playerLoading = false
  var trayMenu: NSMenu? { item?.menu }
  private var timerEntry: NSMenuItem?
  private var paused = false
  private var running = false
  private var presets: [[String: String]] = []
  private var selectedID: String?
  private var updateVersion: String?
  private var updateReady = false

  func setUpdateAvailable(_ version: String?, ready: Bool = false) {
    updateVersion = version
    updateReady = ready
    rebuildMenu()
    channel.invokeMethod("action", arguments: [
      "action": "updateStatus", "version": version as Any? ?? NSNull(), "ready": ready,
    ])
  }

  init(window: NSWindow, controller: FlutterViewController) {
    self.window = window
    channel = FlutterMethodChannel(name: "dev.soyjanks.walone/desktop", binaryMessenger: controller.engine.binaryMessenger)
    appearanceChannel = FlutterMethodChannel(name: "dev.soyjanks.walone/appearance", binaryMessenger: controller.engine.binaryMessenger)
    super.init()
    restoreTray()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "initialize":
        self.restoreTray()
        result(self.status())
      case "status": result(self.status())
      case "checkForUpdates":
        (NSApp.delegate as? AppDelegate)?.checkForUpdates(nil)
        result(nil)
      case "setLaunchAtLogin":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "arguments", message: "Ожидается переключатель автозапуска", details: nil)); return
        }
        if enabled {
          let status = SMAppService.mainApp.status
          if status != .enabled && status != .requiresApproval { try SMAppService.mainApp.register() }
        } else if SMAppService.mainApp.status != .notRegistered {
          try SMAppService.mainApp.unregister()
        }
        result(nil)
      case "openLoginSettings": SMAppService.openSystemSettingsLoginItems(); result(nil)
      case "restoreTray": self.restoreTray(); result(nil)
      case "hide": self.hide(); result(nil)
      case "show": self.show(); result(nil)
      case "setVkLoginVisible":
        guard let visible = call.arguments as? Bool,
              let login = NSApp.windows.first(where: { $0.title == "Вход VK — Walone" }) else {
          result(FlutterError(code: "vkWindow", message: "Окно входа VK недоступно", details: nil)); return
        }
        if visible { login.makeKeyAndOrderFront(nil) }
        else { login.orderOut(nil) }
        result(nil)
      case "quit":
        result(nil)
        // terminateLater запускает вложенный цикл AppKit; dispatch-очередь
        // не должна удерживаться во время ожидания ответа Flutter.
        NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
      case "updateTimerTray":
        guard let data = call.arguments as? [String: Any] else {
          result(FlutterError(code: "arguments", message: "Ожидается состояние таймера", details: nil)); return
        }
        let title = data["title"] as? String ?? ""
        let running = data["running"] as? Bool ?? false
        let rebuild = self.timerTitle.isEmpty != title.isEmpty || self.timerRunning != running
        self.timerTitle = title
        self.timerRunning = running
        let time = data["time"] as? String ?? ""
        self.item?.length = time.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        self.item?.button?.title = time.isEmpty ? "" : " " + time
        self.item?.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        self.item?.button?.toolTip = title.isEmpty ? "Walone — атмосфера работы" : title
        self.item?.button?.setAccessibilityLabel(title.isEmpty ? "Walone" : "Walone: " + title)
        if rebuild { self.rebuildMenu() }
        else { self.timerEntry?.title = title }
        result(nil)
      case "updatePlayerTray":
        guard let data = call.arguments as? [String: Any] else {
          result(FlutterError(code: "arguments", message: "Ожидается состояние плеера", details: nil)); return
        }
        self.playerTitle = data["title"] as? String ?? ""
        self.playerPlaying = data["playing"] as? Bool ?? false
        self.playerAvailable = data["available"] as? Bool ?? false
        self.playerLoading = data["loading"] as? Bool ?? false
        self.rebuildMenu()
        result(nil)
      case "updateMusicTray":
        let bars = call.arguments as? [Double]
        guard call.arguments == nil || call.arguments is NSNull ||
                (bars?.count == 5 && bars!.allSatisfy({ $0.isFinite && (0...1).contains($0) })) else {
          result(FlutterError(code: "arguments", message: "Ожидаются пять уровней звука", details: nil)); return
        }
        self.item?.button?.image = Self.musicTrayImage(
          NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : bars)
        result(nil)
      case "updateTray":
        guard let data = call.arguments as? [String: Any] else {
          result(FlutterError(code: "arguments", message: "Ожидается состояние трея", details: nil)); return
        }
        self.paused = data["paused"] as? Bool ?? false
        self.running = data["running"] as? Bool ?? false
        self.presets = data["presets"] as? [[String: String]] ?? []
        self.selectedID = data["selectedID"] as? String
        self.rebuildMenu()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "desktop", message: error.localizedDescription, details: nil))
    }
  }

  private func status() -> [String: Any] {
    let login: String
    switch SMAppService.mainApp.status {
    case .enabled: login = "enabled"
    case .requiresApproval: login = "requiresApproval"
    case .notFound: login = "notFound"
    default: login = "disabled"
    }
    return ["login": login, "trayAvailable": item?.isVisible == true, "windowVisible": window?.isVisible == true, "timerTitle": timerTitle, "trayTimer": item?.button?.title ?? "", "updateVersion": updateVersion as Any? ?? NSNull(), "updateReady": updateReady]
  }

  func restoreTray() {
    if item == nil {
      item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      item?.autosaveName = "WaloneFlutterStatusItem"
      item?.button?.image = Self.musicTrayImage(nil)
      item?.button?.imagePosition = .imageLeading
      item?.button?.toolTip = "Walone — атмосфера работы"
      item?.button?.setAccessibilityLabel("Walone")
    }
    item?.isVisible = true
    rebuildMenu()
  }

  static func musicTrayImage(_ bars: [Double]?) -> NSImage {
    let heights = bars?.map { 3 + 12 * $0 } ?? [5.0, 10.0, 15.0, 10.0, 5.0]
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      NSColor.black.setFill()
      for (index, height) in heights.enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 0.8 + Double(index) * 3.5,
                                       y: (18 - height) / 2, width: 2.4, height: height),
                     xRadius: 1.2, yRadius: 1.2).fill()
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  private func rebuildMenu() {
    let menu = NSMenu()
    timerEntry = nil
    let open = NSMenuItem(title: "Открыть", action: #selector(performAction(_:)), keyEquivalent: "")
    open.target = self
    open.representedObject = "open"
    menu.addItem(open)
    menu.addItem(.separator())
    let music = NSMenuItem(title: playerTitle.isEmpty ? "Моя музыка…" : playerTitle,
                           action: #selector(performAction(_:)), keyEquivalent: "")
    music.target = self
    music.representedObject = "music"
    menu.addItem(music)
    for (title, action, enabled) in [
      (playerPlaying ? "Приостановить музыку" : "Воспроизвести музыку", "toggleMusic", playerAvailable && !playerLoading),
      ("Предыдущий трек", "previousTrack", !playerTitle.isEmpty && !playerLoading),
      ("Следующий трек", "nextTrack", !playerTitle.isEmpty && !playerLoading),
    ] {
      let entry = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
      entry.target = self
      entry.representedObject = action
      entry.isEnabled = enabled
      menu.addItem(entry)
    }
    menu.addItem(.separator())
    let timers = NSMenuItem(title: timerTitle.isEmpty ? "Таймеры…" : timerTitle,
                           action: #selector(performAction(_:)), keyEquivalent: "")
    timers.target = self
    timers.representedObject = "timers"
    menu.addItem(timers)
    timerEntry = timers
    if !timerTitle.isEmpty {
      for (title, action) in [(timerRunning ? "Приостановить таймер" : "Запустить таймер", "toggleTimer"),
                               ("Сбросить таймер", "resetTimer")] {
        let entry = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
        entry.target = self
        entry.representedObject = action
        menu.addItem(entry)
      }
    }
    menu.addItem(.separator())
    for (title, action, enabled) in [
      (paused ? "Продолжить все звуки" : "Пауза всех звуков", "togglePause", true),
      ("Пауза на 15 минут", "pause15", true),
      ("Выключить фон", "stopBackground", running),
      ("Атмосфера…", "atmosphere", true),
      ("Настройки…", "settings", true),
    ] {
      let entry = NSMenuItem(title: title, action: #selector(performAction(_:)), keyEquivalent: "")
      entry.target = self
      entry.representedObject = action
      entry.isEnabled = enabled
      menu.addItem(entry)
    }
    if !presets.isEmpty {
      let entry = NSMenuItem(title: "Мои наборы", action: nil, keyEquivalent: "")
      let submenu = NSMenu()
      for preset in presets {
        guard let id = preset["id"], let name = preset["name"] else { continue }
        let child = NSMenuItem(title: name, action: #selector(selectPreset(_:)), keyEquivalent: "")
        child.target = self
        child.representedObject = id
        child.state = id == selectedID ? .on : .off
        submenu.addItem(child)
      }
      entry.submenu = submenu
      menu.addItem(entry)
    }
    menu.autoenablesItems = false
    menu.addItem(.separator())
    let updateTitle = updateReady ? "Обновить и перезапустить" :
      (updateVersion.map { "Доступна версия \($0)…" } ?? "Проверить обновления…")
    let update = NSMenuItem(title: updateTitle, action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
    update.target = NSApp.delegate
    menu.addItem(update)
    let quit = NSMenuItem(title: "Завершить Walone", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    quit.target = NSApp
    menu.addItem(quit)
    item?.menu = menu
  }

  @objc private func performAction(_ sender: NSMenuItem) {
    guard let action = sender.representedObject as? String else { return }
    if action == "open" {
      show()
      return
    }
    if ["settings", "atmosphere", "timers", "music"].contains(action) { show() }
    channel.invokeMethod("action", arguments: ["action": action])
  }

  @objc private func selectPreset(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String else { return }
    channel.invokeMethod("action", arguments: ["action": "preset", "id": id])
  }

  @objc func showSettings() {
    show()
    channel.invokeMethod("action", arguments: ["action": "settings"])
  }

  func show() {
    appearanceChannel.invokeMethod("visibility", arguments: true)
    restoreTray()
    NSApp.setActivationPolicy(.regular)
    NSApp.unhide(nil)
    if window?.isMiniaturized == true { window?.deminiaturize(nil) }
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func hide() {
    restoreTray()
    window?.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    appearanceChannel.invokeMethod("visibility", arguments: false)
  }
}
