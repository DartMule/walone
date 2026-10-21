import Cocoa
import AVFoundation
import Carbon
import FlutterMacOS
import XCTest
@testable import Walone_Flutter

private var launchEventForTest: NSAppleEventDescriptor?

private final class TransientFailureEngine: AVAudioEngine, @unchecked Sendable {
  private var failNextStart = true
  override func start() throws {
    if failNextStart {
      failNextStart = false
      throw NSError(domain: NSOSStatusErrorDomain, code: -10875)
    }
    try super.start()
  }
}

extension NSAppleEventManager {
  @objc fileprivate func waloneTestCurrentEvent() -> NSAppleEventDescriptor? {
    launchEventForTest
  }
}

class RunnerTests: XCTestCase {

  func testUpdateClickDuringBackgroundDownloadShowsFeedback() {
    let delegate = NSApp.delegate as! AppDelegate
    let window = NSApp.windows.compactMap { $0 as? MainFlutterWindow }.first!
    var checked = false
    delegate.performUpdateCheck(canCheck: false) { checked = true }
    XCTAssertFalse(checked)
    XCTAssertNotNil(window.attachedSheet)
    if let sheet = window.attachedSheet { window.endSheet(sheet) }
    delegate.performUpdateCheck(canCheck: true) { checked = true }
    XCTAssertTrue(checked)
  }

  func testSRGBProjectKeepsImpellerAndFlutterSelectorContract() {
    // Внутренний hook должен по-прежнему существовать в закреплённом Flutter.
    let wideGamut = NSSelectorFromString("enableWideGamut")
    let impeller = NSSelectorFromString("enableImpeller")
    XCTAssertTrue(FlutterDartProject.instancesRespond(to: wideGamut))
    XCTAssertTrue(FlutterDartProject.instancesRespond(to: impeller))
    let project = WaloneDartProject()
    XCTAssertEqual(project.value(forKey: "enableWideGamut") as? Bool, false)
    XCTAssertEqual(project.value(forKey: "enableImpeller") as? Bool, true)
    XCTAssertTrue(FlutterDartProject.instancesRespond(to: NSSelectorFromString("enableSDFs")))
    XCTAssertEqual(project.value(forKey: "enableSDFs") as? Bool, true)
    // Данные Unicode нужны для позиции курсора и границ символов.
    let icuPath = project.value(forKey: "ICUDataPath") as? String
    XCTAssertNotNil(icuPath)
    XCTAssertEqual(icuPath, FlutterDartProject().value(forKey: "ICUDataPath") as? String)
    if let icuPath { XCTAssertTrue(FileManager.default.fileExists(atPath: icuPath)) }
  }

  func testTrayOpensHiddenWindowAndReflectsPlayerAndTimerState() {
    let controller = FlutterViewController()
    let window = NSWindow(contentViewController: controller)
    let bridge = DesktopBridge(window: window, controller: controller)
    func update(_ method: String, _ state: [String: Any]) {
      bridge.handle(FlutterMethodCall(methodName: method, arguments: state)) {
        XCTAssertNil($0)
      }
    }
    func entry(_ action: String) -> NSMenuItem? {
      bridge.trayMenu?.items.first { $0.representedObject as? String == action }
    }
    defer { window.orderOut(nil) }
    XCTAssertEqual(bridge.trayMenu?.items.first?.title, "Открыть")
    bridge.setUpdateAvailable("0.2.0")
    XCTAssertTrue(bridge.trayMenu!.items.contains { $0.title == "Доступна версия 0.2.0…" })
    bridge.setUpdateAvailable(nil)
    XCTAssertTrue(bridge.trayMenu!.items.contains { $0.title == "Проверить обновления…" })
    bridge.setUpdateAvailable("0.2.0", ready: true)
    XCTAssertTrue(bridge.trayMenu!.items.contains { $0.title == "Обновить и перезапустить" })
    bridge.handle(FlutterMethodCall(methodName: "status", arguments: nil)) { result in
      let status = result as! [String: Any]
      XCTAssertEqual(status["updateVersion"] as? String, "0.2.0")
      XCTAssertEqual(status["updateReady"] as? Bool, true)
    }
    bridge.setUpdateAvailable(nil)
    bridge.hide()
    XCTAssertFalse(window.isVisible)
    let open = entry("open")!
    XCTAssertTrue(NSApp.sendAction(open.action!, to: open.target, from: open))
    XCTAssertTrue(window.isVisible)
    update("updatePlayerTray", ["title": "Дождь", "playing": true, "available": true])
    XCTAssertEqual(entry("music")?.title, "Дождь")
    XCTAssertEqual(entry("toggleMusic")?.title, "Приостановить музыку")
    XCTAssertEqual(entry("nextTrack")?.isEnabled, true)
    update("updatePlayerTray", ["playing": false, "available": false])
    XCTAssertEqual(entry("toggleMusic")?.isEnabled, false)
    XCTAssertEqual(entry("nextTrack")?.isEnabled, false)
    update("updateTimerTray", ["title": "Рабочая сессия · 00:24:59", "time": "", "running": true])
    XCTAssertEqual(entry("toggleTimer")?.title, "Приостановить таймер")
    update("updateTimerTray", ["title": "Рабочая сессия · 00:24:59 · пауза", "time": "", "running": false])
    XCTAssertEqual(entry("toggleTimer")?.title, "Запустить таймер")
    update("updateTimerTray", ["title": "", "time": "", "running": false])
    XCTAssertNil(entry("resetTimer"))
  }

  func testTrayVolumesUpdateWithoutReplacingTrackedMenu() {
    let controller = FlutterViewController()
    let window = NSWindow(contentViewController: controller)
    let bridge = DesktopBridge(window: window, controller: controller)
    defer { window.orderOut(nil) }
    let menu = bridge.trayMenu!
    let sliders = menu.items.compactMap { item in
      item.view?.subviews.compactMap { $0 as? NSSlider }.first
    }
    XCTAssertEqual(sliders.count, 4)
    bridge.menuWillOpen(menu)
    bridge.handle(FlutterMethodCall(methodName: "updateVolumes", arguments: [
      "master": 0.2, "music": 0.3, "atmosphere": 0.4, "keyboard": 0.5,
      "keyboardEnabled": true,
    ])) { XCTAssertNil($0) }
    XCTAssertEqual(sliders.map { $0.doubleValue }, [0.2, 0.3, 0.4, 0.5])
    XCTAssertTrue(sliders.allSatisfy { $0.isEnabled && $0.isContinuous })
    bridge.handle(FlutterMethodCall(methodName: "updateTray", arguments: ["paused": true])) {
      XCTAssertNil($0)
    }
    XCTAssertTrue(bridge.trayMenu === menu)
    sliders[1].doubleValue = 0.8
    XCTAssertTrue(NSApp.sendAction(sliders[1].action!, to: sliders[1].target, from: sliders[1]))
    bridge.menuDidClose(menu)
    let music = bridge.trayMenu!.items.compactMap { $0.view?.subviews.compactMap { $0 as? NSSlider }.first }
      .first { $0.identifier?.rawValue == "music" }
    XCTAssertEqual(music?.doubleValue, 0.8)
  }

  func testMusicTrayImagesKeepTemplateAndGeometry() {
    let idle = DesktopBridge.musicTrayImage(nil)
    let quiet = DesktopBridge.musicTrayImage([0, 0, 0, 0, 0])
    let loud = DesktopBridge.musicTrayImage([1, 0.5, 1, 0.5, 1])
    for image in [idle, quiet, loud] {
      XCTAssertTrue(image.isTemplate)
      XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
      XCTAssertNotNil(image.tiffRepresentation)
    }
    XCTAssertNotEqual(quiet.tiffRepresentation, loud.tiffRepresentation)
    let wave = DesktopBridge.musicTrayImage([2.0/12, 7.0/12, 1, 7.0/12, 2.0/12])
    XCTAssertEqual(idle.tiffRepresentation, wave.tiffRepresentation)
  }

  func testTransientAudioFailureDoesNotDisableKeysAndNextKeyRecovers() {
    let controller = FlutterViewController()
    let asset = controller.lookupKey(forAsset: "assets/keyboards/brown/key0.wav")
    let directory = Bundle.main.bundleURL.appendingPathComponent(asset).deletingLastPathComponent().deletingLastPathComponent()
    let engine = TransientFailureEngine()
    let audio = KeyboardAudio(engine: engine, resourcesURL: directory)
    let bridge = KeyboardBridge(controller: controller, audio: audio)
    defer { audio.stop() }
    bridge.handle(FlutterMethodCall(methodName: "configure", arguments: ["pack": "brown", "enabled": true, "volume": 0.0])) {
      XCTAssertNil($0)
    }
    bridge.playKey(code: 0)
    bridge.handle(FlutterMethodCall(methodName: "status", arguments: nil)) { result in
      let status = result as? [String: Any]
      XCTAssertEqual(status?["enabled"] as? Bool, true)
      XCTAssertTrue(status?["error"] is String)
    }
    bridge.playKey(code: 49)
    XCTAssertTrue(engine.isRunning)
    bridge.handle(FlutterMethodCall(methodName: "status", arguments: nil)) { result in
      XCTAssertTrue((result as? [String: Any])?["error"] is NSNull)
    }
  }

  func testSystemAndDisplaySleepPauseButWakeDoesNotResume() {
    let controller = FlutterViewController()
    let bridge = KeyboardBridge(controller: controller)
    var reasons: [String] = []
    XCTAssertNil(bridge.onListen(withArguments: nil) { event in
      if let data = event as? [String: String], let reason = data["reason"] {
        reasons.append(reason)
      }
    })
    let center = NSWorkspace.shared.notificationCenter
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    XCTAssertEqual(reasons, ["sleep"])
    center.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    XCTAssertEqual(reasons, ["sleep", "sleep"])
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    center.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
    XCTAssertEqual(reasons, ["sleep", "sleep"])
    XCTAssertNil(bridge.onCancel(withArguments: nil))
  }

  func testFinishLaunchingReachesWindowPresentation() {
    // Повторяем настоящий callback: необязательный метод NSApplicationDelegate
    // отсутствует у FlutterAppDelegate, прямой вызов super вызывает ObjC exception.
    let delegate = NSApp.delegate as! AppDelegate
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    let window = NSApp.windows.compactMap { $0 as? MainFlutterWindow }.first
    XCTAssertNotNil(window)
    XCTAssertEqual(window?.isVisible, true)
  }

  func testLoginEventHidesWindowAndManualReopenRestoresIt() {
    // Подменяем только источник входящего события, не отправляя события в ОС.
    let original = class_getInstanceMethod(NSAppleEventManager.self, #selector(getter: NSAppleEventManager.currentAppleEvent))!
    let substitute = class_getInstanceMethod(NSAppleEventManager.self, #selector(NSAppleEventManager.waloneTestCurrentEvent))!
    method_exchangeImplementations(original, substitute)
    defer {
      method_exchangeImplementations(original, substitute)
      launchEventForTest = nil
    }
    let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication,
      targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
    launchEventForTest = event
    let delegate = NSApp.delegate as! AppDelegate
    let window = NSApp.windows.compactMap { $0 as? MainFlutterWindow }.first
    XCTAssertNotNil(window)
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    XCTAssertEqual(window?.isVisible, false)
    XCTAssertEqual(NSApp.activationPolicy(), .accessory)
    launchEventForTest = nil
    XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false))
    XCTAssertEqual(window?.isVisible, true)
  }

}
