#ifndef RUNNER_DESKTOP_BRIDGE_H_
#define RUNNER_DESKTOP_BRIDGE_H_

#include <windows.h>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <functional>
#include <memory>
#include <string>
#include <vector>

class DesktopBridge {
 public:
  DesktopBridge(HWND window, flutter::BinaryMessenger* messenger,
                std::function<void()> quit);
  ~DesktopBridge();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void Show();
  void Hide();

 private:
  bool RestoreTray();
  void UpdateMusicTray(const flutter::EncodableValue* value);
  void Menu();
  void Action(const std::string& action, const std::string& id = "");
  flutter::EncodableMap Status();
  std::wstring StartupCommand();
  void SetLaunchAtLogin(bool enabled);
  HWND window_;
  std::function<void()> quit_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> appearance_channel_;
  NOTIFYICONDATAW icon_{};
  HICON music_icon_ = nullptr;
  UINT taskbar_created_;
  bool tray_available_ = false;
  std::string timer_title_utf8_;
  std::wstring timer_title_;
  bool timer_running_ = false;
  bool paused_ = false;
  bool running_ = false;
  std::string selected_;
  struct Preset { std::string id; std::wstring name; };
  std::vector<Preset> presets_;
};

#endif
