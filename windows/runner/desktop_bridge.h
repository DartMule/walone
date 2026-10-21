#ifndef RUNNER_DESKTOP_BRIDGE_H_
#define RUNNER_DESKTOP_BRIDGE_H_

#include <windows.h>
#include <array>
#include <cstdint>
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
  void RefreshMusicIcon();
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
  uint32_t tray_color_ = 0;
  UINT taskbar_created_;
  bool tray_available_ = false;
  std::string timer_title_utf8_;
  std::wstring timer_title_;
  bool timer_running_ = false;
  std::wstring player_title_;
  bool player_playing_ = false;
  bool player_available_ = false;
  bool player_loading_ = false;
  std::array<double, 4> volumes_{0.7, 0.7, 1, 0.35};
  bool keyboard_volume_enabled_ = false;
  std::array<double, 5> music_levels_{2.0 / 12, 7.0 / 12, 1, 7.0 / 12, 2.0 / 12};
  bool paused_ = false;
  bool running_ = false;
  std::string selected_;
  struct Preset { std::string id; std::wstring name; };
  std::vector<Preset> presets_;
};

#endif
