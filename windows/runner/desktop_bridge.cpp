#include "desktop_bridge.h"

#include <flutter/standard_method_codec.h>
#include <dwmapi.h>
#include <stdexcept>
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace {
constexpr UINT kTrayMessage = WM_APP + 44;
constexpr UINT kReopenMessage = WM_APP + 46;
constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunName[] = L"WaloneFlutter";
constexpr const char* kVolumeChannels[] = {"master", "music", "atmosphere", "keyboard"};
constexpr const wchar_t* kVolumeTitles[] = {L"Общая громкость", L"Музыка", L"Атмосфера", L"Клавиатура"};
constexpr UINT kVolumeCommand = 20;
constexpr UINT kPresetCommand = 100;

std::wstring MenuText(const std::wstring& text) {
  // Данные пользователя не должны превращаться в мнемоники или колонки меню.
  std::wstring result;
  for (const auto c : text) {
    result += c == L'\t' || c == L'\r' || c == L'\n' ? L' ' : c;
    if (c == L'&') result += c;
  }
  return result;
}

uint32_t TrayColor() {
  HIGHCONTRASTW contrast{sizeof(HIGHCONTRASTW)};
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
      (contrast.dwFlags & HCF_HIGHCONTRASTON)) {
    const COLORREF color = GetSysColor(COLOR_WINDOWTEXT);
    return (GetRValue(color) << 16) | (GetGValue(color) << 8) | GetBValue(color);
  }
  DWORD light = 1;
  DWORD bytes = sizeof(light);
  RegGetValueW(HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr, &light, &bytes);
  return light ? 0x000000 : 0xFFFFFF;
}

const flutter::EncodableValue* Field(const flutter::EncodableMap& map, const char* name) {
  const auto found = map.find(flutter::EncodableValue(name));
  return found == map.end() ? nullptr : &found->second;
}
std::string Text(const flutter::EncodableMap& map, const char* name) {
  const auto* value = Field(map, name);
  const auto* text = value ? std::get_if<std::string>(value) : nullptr;
  return text ? *text : "";
}
bool Flag(const flutter::EncodableMap& map, const char* name) {
  const auto* value = Field(map, name);
  const auto* flag = value ? std::get_if<bool>(value) : nullptr;
  return flag && *flag;
}
std::wstring Wide(const std::string& value) {
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), size);
  return result;
}
void Check(LSTATUS status) {
  if (status != ERROR_SUCCESS) throw std::runtime_error("Ошибка Windows: " + std::to_string(status));
}
}

DesktopBridge::DesktopBridge(HWND window, flutter::BinaryMessenger* messenger,
                             std::function<void()> quit)
    : window_(window), quit_(std::move(quit)),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  icon_.cbSize = sizeof(icon_);
  icon_.hWnd = window_;
  icon_.uID = 1;
  icon_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  icon_.uCallbackMessage = kTrayMessage;
  tray_color_ = TrayColor();
  RefreshMusicIcon();
  wcscpy_s(icon_.szTip, L"Walone — атмосфера работы");
  RestoreTray();
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "dev.soyjanks.walone/desktop", &flutter::StandardMethodCodec::GetInstance());
  appearance_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "dev.soyjanks.walone/appearance", &flutter::StandardMethodCodec::GetInstance());
  appearance_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "accessibility") {
      flutter::EncodableMap settings{
          {flutter::EncodableValue("windowVisible"), flutter::EncodableValue(IsWindowVisible(window_) != FALSE)}};
      DWORD transparency = 1;
      DWORD bytes = sizeof(transparency);
      RegGetValueW(HKEY_CURRENT_USER,
          L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
          L"EnableTransparency", RRF_RT_REG_DWORD, nullptr, &transparency, &bytes);
      settings[flutter::EncodableValue("reduceTransparency")] =
          flutter::EncodableValue(transparency == 0);
      HIGHCONTRASTW contrast{sizeof(HIGHCONTRASTW)};
      settings[flutter::EncodableValue("increaseContrast")] = flutter::EncodableValue(
          SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
          (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0);
      DWORD accent;
      BOOL opaque;
      if (SUCCEEDED(DwmGetColorizationColor(&accent, &opaque))) {
        settings[flutter::EncodableValue("accentColor")] =
            flutter::EncodableValue(static_cast<int64_t>(accent | 0xFF000000));
      }
      result->Success(flutter::EncodableValue(settings));
    } else {
      result->NotImplemented();
    }
  });
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    try {
      const auto& method = call.method_name();
      if (method == "initialize" || method == "status") {
        if (method == "initialize") RestoreTray();
        result->Success(flutter::EncodableValue(Status()));
        return;
      }
      if (method == "setLaunchAtLogin") {
        const auto* enabled = call.arguments() ? std::get_if<bool>(call.arguments()) : nullptr;
        if (!enabled) throw std::runtime_error("Ожидается переключатель автозапуска");
        SetLaunchAtLogin(*enabled);
      } else if (method == "openLoginSettings") {
        if (reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", L"ms-settings:startupapps", nullptr, nullptr, SW_SHOWNORMAL)) <= 32)
          throw std::runtime_error("Не удалось открыть настройки автозапуска Windows");
      } else if (method == "restoreTray") {
        if (!RestoreTray()) throw std::runtime_error("Не удалось восстановить значок трея");
      } else if (method == "show") { Show();
      } else if (method == "hide") { Hide();
      } else if (method == "quit") {
        result->Success();
        quit_();
        return;
      } else if (method == "updateTimerTray") {
        const auto* data = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        if (!data) throw std::runtime_error("Ожидается состояние таймера");
        timer_title_utf8_ = Text(*data, "title");
        timer_title_ = Wide(timer_title_utf8_);
        timer_running_ = Flag(*data, "running");
        const auto tip = timer_title_.empty() ? std::wstring(L"Walone — атмосфера работы") : L"Walone: " + timer_title_;
        wcsncpy_s(icon_.szTip, tip.c_str(), _TRUNCATE);
        Shell_NotifyIconW(NIM_MODIFY, &icon_);
      } else if (method == "updateMusicTray") {
        UpdateMusicTray(call.arguments());
      } else if (method == "startWaveform") {
        const auto* data = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        if (!data || Text(*data, "id").empty() || Text(*data, "path").empty())
          throw std::runtime_error("Ожидается путь музыкального файла");
        waveform_.reset();
        waveform_id_ = Text(*data, "id");
        waveform_ = std::make_unique<MusicWaveformReader>(Wide(Text(*data, "path")));
      } else if (method == "readWaveform" || method == "stopWaveform") {
        const auto* id = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
        if (!id) throw std::runtime_error("Ожидается идентификатор визуализации");
        if (method == "stopWaveform") {
          if (*id == waveform_id_) waveform_.reset();
        } else {
          const auto batch = waveform_ && *id == waveform_id_
              ? waveform_->Read() : MusicWaveformReader::Batch{{}, true, false};
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("levels"), flutter::EncodableValue(batch.levels)},
              {flutter::EncodableValue("done"), flutter::EncodableValue(batch.done)},
              {flutter::EncodableValue("failed"), flutter::EncodableValue(batch.failed)}}));
          return;
        }
      } else if (method == "updatePlayerTray") {
        const auto* data = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        if (!data) throw std::runtime_error("Ожидается состояние плеера");
        player_title_ = Wide(Text(*data, "title"));
        player_playing_ = Flag(*data, "playing");
        player_available_ = Flag(*data, "available");
        player_loading_ = Flag(*data, "loading");
      } else if (method == "updateVolumes") {
        const auto* data = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        if (!data) throw std::runtime_error("Ожидаются уровни громкости от 0 до 1");
        auto volumes = volumes_;
        for (size_t i = 0; i < volumes.size(); ++i) {
          const auto* value = Field(*data, kVolumeChannels[i]);
          const auto* level = value ? std::get_if<double>(value) : nullptr;
          if (!level || !std::isfinite(*level) || *level < 0 || *level > 1)
            throw std::runtime_error("Ожидаются уровни громкости от 0 до 1");
          volumes[i] = *level;
        }
        volumes_ = volumes;
        keyboard_volume_enabled_ = Flag(*data, "keyboardEnabled");
      } else if (method == "updateTray") {
        const auto* data = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
        if (!data) throw std::runtime_error("Ожидается состояние трея");
        paused_ = Flag(*data, "paused");
        running_ = Flag(*data, "running");
        selected_ = Text(*data, "selectedID");
        presets_.clear();
        const auto* entries = Field(*data, "presets");
        const auto* list = entries ? std::get_if<flutter::EncodableList>(entries) : nullptr;
        if (list) for (const auto& entry : *list) {
          if (const auto* map = std::get_if<flutter::EncodableMap>(&entry))
            presets_.push_back({Text(*map, "id"), Wide(Text(*map, "name"))});
        }
      } else { result->NotImplemented(); return; }
      result->Success();
    } catch (const std::exception& error) { result->Error("desktop", error.what()); }
  });
}

DesktopBridge::~DesktopBridge() {
  channel_->SetMethodCallHandler(nullptr);
  appearance_channel_->SetMethodCallHandler(nullptr);
  Shell_NotifyIconW(NIM_DELETE, &icon_);
  if (music_icon_) DestroyIcon(music_icon_);
}

void DesktopBridge::UpdateMusicTray(const flutter::EncodableValue* value) {
  const auto* bars = value ? std::get_if<flutter::EncodableList>(value) : nullptr;
  if (value && !std::holds_alternative<std::monostate>(*value) && !bars)
    throw std::runtime_error("Ожидаются пять уровней звука");
  if (bars) {
    if (bars->size() != 5) throw std::runtime_error("Ожидаются пять уровней звука");
    for (const auto& bar : *bars) {
      const auto* level = std::get_if<double>(&bar);
      if (!level || !std::isfinite(*level) || *level < 0 || *level > 1)
        throw std::runtime_error("Некорректный уровень звука");
    }
  }
  BOOL animations = TRUE;
  SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0);
  music_levels_ = {2.0 / 12, 7.0 / 12, 1, 7.0 / 12, 2.0 / 12};
  if (bars && animations) for (size_t i = 0; i < music_levels_.size(); ++i)
    music_levels_[i] = std::get<double>((*bars)[i]);
  RefreshMusicIcon();
}

void DesktopBridge::RefreshMusicIcon() {
  HICON next = nullptr;
  {
    const UINT dpi = GetDpiForWindow(window_);
    const int size = std::max(16, GetSystemMetricsForDpi(SM_CXSMICON, dpi ? dpi : 96));
    const uint32_t ink = 0xFF000000 | tray_color_;
    BITMAPINFO bitmap{};
    bitmap.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bitmap.bmiHeader.biWidth = size;
    bitmap.bmiHeader.biHeight = -size;
    bitmap.bmiHeader.biPlanes = 1;
    bitmap.bmiHeader.biBitCount = 32;
    bitmap.bmiHeader.biCompression = BI_RGB;
    void* pixels = nullptr;
    HBITMAP color = CreateDIBSection(nullptr, &bitmap, DIB_RGB_COLORS, &pixels, nullptr, 0);
    const std::vector<BYTE> mask_bits(((size + 15) / 16) * 2 * size, 0);
    HBITMAP mask = CreateBitmap(size, size, 1, 1, mask_bits.data());
    if (color && mask && pixels) {
      auto* data = static_cast<uint32_t*>(pixels);
      std::fill(data, data + size * size, 0);
      for (int bar = 0; bar < 5; ++bar) {
        const double height = (3 + 12 * music_levels_[bar]) * size / 18;
        const double center = (2 + bar * 3.5) * size / 18;
        const double radius = 1.2 * size / 18;
        for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
          const double dx = x + 0.5 - center;
          const double dy = std::max(0.0, std::abs(y + 0.5 - size / 2.0) - height / 2 + radius);
          if (dx * dx + dy * dy <= radius * radius) data[y * size + x] = ink;
        }
      }
      ICONINFO info{};
      info.fIcon = TRUE;
      info.hbmColor = color;
      info.hbmMask = mask;
      next = CreateIconIndirect(&info);
    }
    if (color) DeleteObject(color);
    if (mask) DeleteObject(mask);
    if (!next) return;
  }
  const auto previous = music_icon_;
  music_icon_ = next;
  icon_.hIcon = next;
  auto update = icon_;
  update.uFlags = NIF_ICON;
  Shell_NotifyIconW(NIM_MODIFY, &update);
  if (previous) DestroyIcon(previous);
}

bool DesktopBridge::RestoreTray() {
  // Сначала обновление; после перезапуска Explorer значок нужно создать заново.
  tray_available_ = Shell_NotifyIconW(NIM_MODIFY, &icon_) != FALSE ||
                    Shell_NotifyIconW(NIM_ADD, &icon_) != FALSE;
  if (tray_available_) {
    icon_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &icon_);
  }
  return tray_available_;
}

void DesktopBridge::Show() {
  RestoreTray();
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
}

void DesktopBridge::Hide() {
  // Если трея нет, оставляем доступное окно вместо невидимого процесса.
  ShowWindow(window_, RestoreTray() ? SW_HIDE : SW_SHOWNORMAL);
}

void DesktopBridge::Action(const std::string& action, const std::string& id) {
  if (action == "settings" || action == "atmosphere" || action == "timers" || action == "music") Show();
  channel_->InvokeMethod("action", std::make_unique<flutter::EncodableValue>(
      flutter::EncodableMap{{flutter::EncodableValue("action"), flutter::EncodableValue(action)},
                            {flutter::EncodableValue("id"), flutter::EncodableValue(id)}}));
}

void DesktopBridge::Menu() {
  const auto presets = presets_;
  HMENU menu = CreatePopupMenu();
  AppendMenuW(menu, MF_STRING, 10, L"Открыть Walone");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  for (size_t i = 0; i < volumes_.size(); ++i) {
    const int percent = static_cast<int>(std::lround(volumes_[i] * 100));
    const auto title = std::wstring(kVolumeTitles[i]) + L"\t" + std::to_wstring(percent) + L" %";
    HMENU levels = CreatePopupMenu();
    for (int level = 0; level <= 10; ++level) {
      const auto label = std::to_wstring(level * 10) + L" %";
      AppendMenuW(levels, MF_STRING | (percent == level * 10 ? MF_CHECKED : 0),
          kVolumeCommand + i * 11 + level, label.c_str());
    }
    AppendMenuW(menu, MF_POPUP | (i == 3 && !keyboard_volume_enabled_ ? MF_GRAYED : 0),
        reinterpret_cast<UINT_PTR>(levels), title.c_str());
  }
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  const auto player_title = MenuText(player_title_);
  AppendMenuW(menu, MF_STRING, 11, player_title.empty() ? L"Моя музыка…" : player_title.c_str());
  AppendMenuW(menu, MF_STRING | (player_available_ && !player_loading_ ? 0 : MF_GRAYED),
      12, player_playing_ ? L"Приостановить музыку" : L"Воспроизвести музыку");
  const UINT track_flags = MF_STRING | (!player_title_.empty() && !player_loading_ ? 0 : MF_GRAYED);
  AppendMenuW(menu, track_flags, 13, L"Предыдущий трек");
  AppendMenuW(menu, track_flags, 14, L"Следующий трек");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, 7, timer_title_.empty() ? L"Таймеры…" : timer_title_.c_str());
  if (!timer_title_.empty()) {
    AppendMenuW(menu, MF_STRING, 8, timer_running_ ? L"Приостановить таймер" : L"Запустить таймер");
    AppendMenuW(menu, MF_STRING, 9, L"Сбросить таймер");
  }
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, 1, paused_ ? L"Продолжить все звуки" : L"Пауза всех звуков");
  AppendMenuW(menu, MF_STRING, 2, L"Пауза на 15 минут");
  AppendMenuW(menu, MF_STRING | (running_ ? 0 : MF_GRAYED), 3, L"Выключить фон");
  AppendMenuW(menu, MF_STRING, 4, L"Атмосфера…");
  AppendMenuW(menu, MF_STRING, 5, L"Настройки…");
  if (!presets.empty()) {
    HMENU submenu = CreatePopupMenu();
    for (size_t i = 0; i < presets.size(); ++i) {
      const auto name = MenuText(presets[i].name);
      AppendMenuW(submenu, MF_STRING | (presets[i].id == selected_ ? MF_CHECKED : 0), kPresetCommand + i, name.c_str());
    }
    AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(submenu), L"Мои наборы");
  }
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, 6, L"Завершить Walone");
  POINT position;
  GetCursorPos(&position);
  NOTIFYICONIDENTIFIER identifier{sizeof(identifier)};
  identifier.hWnd = window_;
  identifier.uID = icon_.uID;
  RECT rect;
  if (SUCCEEDED(Shell_NotifyIconGetRect(&identifier, &rect))) {
    position = {(rect.left + rect.right) / 2, rect.top};
  }
  SetForegroundWindow(window_);
  const UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
      position.x, position.y, 0, window_, nullptr);
  PostMessage(window_, WM_NULL, 0, 0);
  // Обновления Flutter во вложенном message loop могут заменить presets_.
  std::string preset;
  if (command >= kPresetCommand && command - kPresetCommand < presets.size()) preset = presets[command - kPresetCommand].id;
  DestroyMenu(menu);
  if (command >= kVolumeCommand && command < kVolumeCommand + volumes_.size() * 11) {
    const UINT choice = command - kVolumeCommand;
    channel_->InvokeMethod("action", std::make_unique<flutter::EncodableValue>(
        flutter::EncodableMap{
          {flutter::EncodableValue("action"), flutter::EncodableValue("volume")},
          {flutter::EncodableValue("channel"), flutter::EncodableValue(kVolumeChannels[choice / 11])},
          {flutter::EncodableValue("value"), flutter::EncodableValue((choice % 11) / 10.0)}}));
    return;
  }
  switch (command) {
    case 1: Action("togglePause"); break;
    case 2: Action("pause15"); break;
    case 3: Action("stopBackground"); break;
    case 4: Action("atmosphere"); break;
    case 5: Action("settings"); break;
    case 6: quit_(); break;
    case 7: Action("timers"); break;
    case 8: Action("toggleTimer"); break;
    case 9: Action("resetTimer"); break;
    case 10: Show(); break;
    case 11: Action("music"); break;
    case 12: Action("toggleMusic"); break;
    case 13: Action("previousTrack"); break;
    case 14: Action("nextTrack"); break;
    default: if (!preset.empty()) Action("preset", preset); break;
  }
}

bool DesktopBridge::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_SETTINGCHANGE || message == WM_THEMECHANGED || message == WM_DPICHANGED) {
    tray_color_ = TrayColor();
    RefreshMusicIcon();
  }
  if (message == WM_SHOWWINDOW) {
    appearance_channel_->InvokeMethod("visibility",
        std::make_unique<flutter::EncodableValue>(wparam != FALSE));
  }
  if (message == taskbar_created_) {
    if (!RestoreTray() && !IsWindowVisible(window_)) ShowWindow(window_, SW_SHOWNORMAL);
    return true;
  }
  if (message == kReopenMessage) { Show(); return true; }
  if (message != kTrayMessage) return false;
  const auto event = LOWORD(lparam);
  if (event == WM_CONTEXTMENU || event == NIN_KEYSELECT || event == NIN_SELECT) Menu();
  if (event == WM_LBUTTONDBLCLK) Show();
  return true;
}

std::wstring DesktopBridge::StartupCommand() {
  std::wstring path(32768, L'\0');
  const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (!size || size >= path.size()) throw std::runtime_error("Не удалось определить путь Walone");
  path.resize(size);
  return L"\"" + path + L"\" --autostart";
}

flutter::EncodableMap DesktopBridge::Status() {
  DWORD bytes = 0;
  std::string login = "disabled";
  auto status = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunName, RRF_RT_REG_SZ, nullptr, nullptr, &bytes);
  if (status == ERROR_SUCCESS) {
    std::wstring value(bytes / sizeof(wchar_t), L'\0');
    Check(RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunName, RRF_RT_REG_SZ, nullptr, value.data(), &bytes));
    value.resize(wcsnlen_s(value.c_str(), value.size()));
    if (value == StartupCommand()) login = "enabled";
  } else if (status != ERROR_FILE_NOT_FOUND) { Check(status); }
  return {{flutter::EncodableValue("login"), flutter::EncodableValue(login)},
          {flutter::EncodableValue("trayAvailable"), flutter::EncodableValue(tray_available_)},
          {flutter::EncodableValue("timerTitle"), flutter::EncodableValue(timer_title_utf8_)},
          {flutter::EncodableValue("windowVisible"), flutter::EncodableValue(IsWindowVisible(window_) != FALSE)}};
}

void DesktopBridge::SetLaunchAtLogin(bool enabled) {
  HKEY key = nullptr;
  if (enabled) {
    const auto command = StartupCommand();
    if (command.size() > 260) throw std::runtime_error("Путь слишком длинный для автозапуска Windows; переместите Walone в более короткий путь");
    Check(RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr));
    const auto status = RegSetValueExW(key, kRunName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()), static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
    Check(status);
  } else {
    const auto opened = RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key);
    if (opened == ERROR_FILE_NOT_FOUND) return;
    Check(opened);
    const auto status = RegDeleteValueW(key, kRunName);
    RegCloseKey(key);
    if (status != ERROR_FILE_NOT_FOUND) Check(status);
  }
}
