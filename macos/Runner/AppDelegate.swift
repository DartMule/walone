import Cocoa
import Carbon
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
  private var terminating = false
  private var replied = false
  private var updaterController: SPUStandardUpdaterController?
  private var installUpdate: (() -> Void)?

  private var mainWindow: MainFlutterWindow? {
    NSApp.windows.compactMap { $0 as? MainFlutterWindow }.first
  }

  private var isLoginEvent: Bool {
    let event = NSAppleEventManager.shared().currentAppleEvent
    return event?.eventID == kAEOpenApplication &&
      event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // FlutterAppDelegate не реализует этот необязательный callback AppKit.
    if isLoginEvent || CommandLine.arguments.contains("--autostart") { mainWindow?.desktopBridge?.hide() }
    else { mainWindow?.desktopBridge?.show() }
    #if !DEBUG
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: self, userDriverDelegate: self
    )
    if let updater = updaterController?.updater, updater.automaticallyChecksForUpdates {
      // Проверяем при каждом запуске, не дожидаясь очередного интервала Sparkle.
      updater.checkForUpdatesInBackground()
    }
    #endif
  }

  @objc func showSettings(_ sender: Any?) { mainWindow?.desktopBridge?.showSettings() }

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    mainWindow?.desktopBridge?.setUpdateAvailable(item.displayVersionString)
  }

  func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
      forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
    mainWindow?.desktopBridge?.setUpdateAvailable(update.displayVersionString)
  }

  func standardUserDriverWillFinishUpdateSession() {
    if installUpdate == nil { mainWindow?.desktopBridge?.setUpdateAvailable(nil) }
  }

  func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
      immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
    installUpdate = immediateInstallHandler
    mainWindow?.desktopBridge?.setUpdateAvailable(item.displayVersionString, ready: true)
    return true
  }

  @objc func checkForUpdates(_ sender: Any?) {
    guard let updaterController else {
      let alert = NSAlert()
      alert.messageText = "Обновления доступны в Release-сборке"
      alert.informativeText = "Отладочную сборку обновляют из исходников."
      alert.runModal()
      return
    }
    NSApp.activate(ignoringOtherApps: true)
    if let installUpdate {
      installUpdate()
      return
    }
    if updaterController.updater.canCheckForUpdates {
      updaterController.checkForUpdates(sender)
    }
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !isLoginEvent { mainWindow?.desktopBridge?.show() }
    return false
  }

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !terminating else { return .terminateLater }
    guard let controller = sender.windows.compactMap({ $0.contentViewController as? FlutterViewController }).first else { return .terminateNow }
    terminating = true
    let channel = FlutterMethodChannel(name: "dev.soyjanks.walone/workspace", binaryMessenger: controller.engine.binaryMessenger)
    // Даём Dart сохранить позицию и остановить только собственные процессы импорта.
    let finish = { [weak self] in
      guard let self, !self.replied else { return }
      self.replied = true
      sender.reply(toApplicationShouldTerminate: true)
    }
    // В объединённом потоке Flutter ответ может прийти до возврата terminateLater.
    channel.invokeMethod("shutdown", arguments: nil) { _ in
      DispatchQueue.main.async(execute: finish)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: finish)
    return .terminateLater
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
