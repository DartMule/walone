#include "flutter_window.h"

#include <optional>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool autostart)
    : project_(project), autostart_(autostart) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  keyboard_bridge_ = std::make_unique<KeyboardBridge>(GetHandle(), flutter_controller_->engine()->messenger());
  workspace_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "dev.soyjanks.walone/workspace", &flutter::StandardMethodCodec::GetInstance());
  desktop_bridge_ = std::make_unique<DesktopBridge>(GetHandle(), flutter_controller_->engine()->messenger(), [this]() { Quit(); });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (autostart_) desktop_bridge_->Hide();
    else desktop_bridge_->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  desktop_bridge_.reset();
  workspace_channel_.reset();
  keyboard_bridge_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::Quit() {
  if (closing_ || !workspace_channel_) return;
  closing_ = true;
  const HWND hwnd = GetHandle();
  SetTimer(hwnd, 0x5741, 5000, nullptr);
  auto finish = [hwnd]() { if (IsWindow(hwnd)) { KillTimer(hwnd, 0x5741); PostMessage(hwnd, WM_APP + 43, 0, 0); } };
  workspace_channel_->InvokeMethod("shutdown", nullptr,
      std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
          [finish](const flutter::EncodableValue*) { finish(); },
          [finish](const std::string&, const std::string&, const flutter::EncodableValue*) { finish(); },
          [finish]() { finish(); }));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && desktop_bridge_) {
    if (!closing_) desktop_bridge_->Hide();
    return 0;
  }
  if (message == WM_APP + 43) { DestroyWindow(hwnd); return 0; }
  if (message == WM_TIMER && wparam == 0x5741 && closing_) { KillTimer(hwnd, 0x5741); DestroyWindow(hwnd); return 0; }
  if (desktop_bridge_ && desktop_bridge_->HandleMessage(message, wparam, lparam)) return 0;
  if (message == WM_GETMINMAXINFO) {
    auto* limits = reinterpret_cast<MINMAXINFO*>(lparam);
    const UINT dpi = GetDpiForWindow(hwnd);
    limits->ptMinTrackSize.x = MulDiv(560, dpi ? dpi : 96, 96);
    limits->ptMinTrackSize.y = MulDiv(680, dpi ? dpi : 96, 96);
    return 0;
  }
  if (keyboard_bridge_) keyboard_bridge_->HandleMessage(message, wparam, lparam);
  if (message == WM_INPUT) return DefWindowProc(hwnd, message, wparam, lparam);

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
