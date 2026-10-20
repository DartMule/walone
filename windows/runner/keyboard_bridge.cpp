#include "keyboard_bridge.h"

#include <flutter/standard_method_codec.h>
#include <flutter/event_stream_handler_functions.h>
#include <wtsapi32.h>

#include <algorithm>
#include <cmath>
#include <stdexcept>

#include "keyboard_wav.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;

void Check(HRESULT result) {
  if (FAILED(result)) throw std::runtime_error("Не удалось запустить XAudio2. Проверьте аудиоустройство.");
}

std::filesystem::path AssetDirectory() {
  std::array<wchar_t, 32768> path{};
  const DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) throw std::runtime_error("Не найден каталог приложения");
  return std::filesystem::path(path.data()).parent_path() / L"data/flutter_assets/assets/keyboards";
}
}  // namespace

KeyboardBridge::KeyboardBridge(HWND window, flutter::BinaryMessenger* messenger) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "dev.soyjanks.walone/keyboard", &flutter::StandardMethodCodec::GetInstance());
  lifecycle_channel_ = std::make_unique<flutter::EventChannel<Value>>(
      messenger, "dev.soyjanks.walone/lifecycle", &flutter::StandardMethodCodec::GetInstance());
  lifecycle_channel_->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<Value>>(
      [this](const Value*, std::unique_ptr<flutter::EventSink<Value>>&& sink) -> std::unique_ptr<flutter::StreamHandlerError<Value>> {
        lifecycle_sink_ = std::move(sink); return nullptr;
      }, [this](const Value*) -> std::unique_ptr<flutter::StreamHandlerError<Value>> {
        lifecycle_sink_.reset(); return nullptr;
      }));
  output_observer_ = new AudioOutputObserver(window_);
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    try {
      const auto& method = call.method_name();
      if (method == "initialize") {
        Initialize();
        result->Success(Status());
      } else if (method == "status") {
        result->Success(Status());
      } else if (method == "statistics") {
        const auto* active = call.arguments() ? std::get_if<bool>(call.arguments()) : nullptr;
        if (!active) throw std::runtime_error("Нет настройки статистики");
        statistics_active_ = *active;
        result->Success(Value(statistics_keys_));
      } else if (method == "configure") {
        const auto* args = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
        if (!args) throw std::runtime_error("Нет настроек клавиатуры");
        const auto id = std::get<std::string>(args->at(Value("pack")));
        const auto count = std::get<int32_t>(args->at(Value("keyCount")));
        const auto enabled = std::get<bool>(args->at(Value("enabled")));
        const double volume = std::get<double>(args->at(Value("volume")));
        if (!std::isfinite(volume) || volume < 0 || volume > 1)
          throw std::runtime_error("Некорректная громкость");
        SelectPack(id, count);
        volume_ = static_cast<float>(volume);
        enabled_ = enabled;
        error_.clear();
        if (!enabled_) StopVoices();
        result->Success();
      } else if (method == "environment") {
        const auto* args = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
        if (!args) throw std::runtime_error("Нет общей громкости");
        const auto volume = std::get<double>(args->at(Value("masterVolume")));
        if (!std::isfinite(volume) || volume < 0 || volume > 1) throw std::runtime_error("Некорректная громкость");
        master_volume_ = static_cast<float>(volume);
        allowed_ = std::get<bool>(args->at(Value("allowed")));
        if (!allowed_) StopVoices();
        result->Success();
      } else if (method == "preview") {
        if (allowed_) Play(0);
        error_.clear();
        result->Success();
      } else if (method == "requestPermission") {
        Initialize();
        result->Success();
      } else if (method == "dispose") {
        Shutdown();
        result->Success();
      } else {
        result->NotImplemented();
      }
    } catch (const std::exception& error) {
      error_ = error.what();
      result->Error("keyboard", error_);
    }
  });
  WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION);
}

KeyboardBridge::~KeyboardBridge() {
  if (output_observer_) { output_observer_->Stop(); output_observer_->Release(); output_observer_ = nullptr; }
  lifecycle_channel_->SetStreamHandler(nullptr);
  lifecycle_sink_.reset();
  channel_->SetMethodCallHandler(nullptr);
  Shutdown();
  WTSUnRegisterSessionNotification(window_);
}

void KeyboardBridge::Initialize() {
  if (sounds_.empty()) SelectPack("brown", 6);
  if (listening_) return;
  RAWINPUTDEVICE keyboard{0x01, 0x06, RIDEV_INPUTSINK | RIDEV_DEVNOTIFY, window_};
  if (!RegisterRawInputDevices(&keyboard, 1, sizeof(keyboard)))
    throw std::runtime_error("Не удалось подключить глобальные нажатия");
  listening_ = true;
}

Value KeyboardBridge::Status() {
  if (FAILED(audio_error_.load())) {
    enabled_ = false;
    error_ = "Аудиоустройство отключено. Проверьте вывод и нажмите «Послушать».";
    DestroyAudio();
  }
  return Value(Map{
    {Value("hasPermission"), Value(true)},
    {Value("listening"), Value(listening_)},
    {Value("secureInput"), Value(false)},
    {Value("enabled"), Value(enabled_)},
    {Value("receivedKeys"), Value(received_keys_)},
    {Value("error"), error_.empty() ? Value() : Value(error_)},
  });
}

void KeyboardBridge::SelectPack(const std::string& id, int key_count) {
  if (id.empty() || id.size() > 80 || key_count < 1 || key_count > 16 ||
      !std::all_of(id.begin(), id.end(), [](unsigned char c) {
        return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-';
      })) throw std::runtime_error("Некорректный набор клавиатуры");
  if (pack_ == id && key_count_ == static_cast<size_t>(key_count)) return;
  std::vector<std::vector<uint8_t>> loaded;
  const auto directory = AssetDirectory() / id;
  for (int i = 0; i < key_count; ++i) loaded.push_back(ReadKeyboardWav(directory / ("key" + std::to_string(i) + ".wav")));
  for (const auto* name : {"space.wav", "enter.wav", "backspace.wav"}) loaded.push_back(ReadKeyboardWav(directory / name));
  // DestroyVoice завершает чтение старых буферов до их освобождения.
  StopVoices();
  sounds_ = std::move(loaded);
  pack_ = id;
  key_count_ = static_cast<size_t>(key_count);
  variation_ = 0;
}

void KeyboardBridge::StartAudio() {
  if (FAILED(audio_error_.load())) DestroyAudio();
  if (!engine_) {
    Check(XAudio2Create(&engine_, 0, XAUDIO2_DEFAULT_PROCESSOR));
    try {
      Check(engine_->RegisterForCallbacks(this));
      Check(engine_->CreateMasteringVoice(&master_));
    } catch (...) {
      DestroyAudio();
      throw;
    }
  }
}

void KeyboardBridge::StopVoices() {
  for (auto& voice : voices_) {
    if (voice) { voice->DestroyVoice(); voice = nullptr; }
  }
  next_voice_ = 0;
}

void KeyboardBridge::DestroyAudio() {
  StopVoices();
  if (master_) { master_->DestroyVoice(); master_ = nullptr; }
  if (engine_) {
    engine_->UnregisterForCallbacks(this);
    engine_->Release();
    engine_ = nullptr;
  }
  audio_error_.store(S_OK);
}

void KeyboardBridge::Play(int group) {
  if (sounds_.empty()) throw std::runtime_error("Сначала выберите клавиатуру");
  StartAudio();
  size_t index = next_voice_;
  for (size_t i = 0; i < voices_.size(); ++i) {
    XAUDIO2_VOICE_STATE state{};
    if (voices_[i]) voices_[i]->GetState(&state, XAUDIO2_VOICE_NOSAMPLESPLAYED);
    if (state.BuffersQueued == 0) { index = i; break; }
  }
  auto& voice = voices_[index];
  if (voice) {
    XAUDIO2_VOICE_STATE state{};
    voice->GetState(&state, XAUDIO2_VOICE_NOSAMPLESPLAYED);
    if (state.BuffersQueued != 0) { voice->DestroyVoice(); voice = nullptr; }
  }
  if (!voice) {
    WAVEFORMATEX format{};
    format.wFormatTag = WAVE_FORMAT_PCM;
    format.nChannels = 1;
    format.nSamplesPerSec = 48000;
    format.nAvgBytesPerSec = 96000;
    format.nBlockAlign = 2;
    format.wBitsPerSample = 16;
    Check(engine_->CreateSourceVoice(&voice, &format));
  }
  const size_t sample = group == 0 ? variation_++ % key_count_ : key_count_ + static_cast<size_t>(group - 1);
  const auto& sound = sounds_.at(sample);
  XAUDIO2_BUFFER buffer{};
  buffer.AudioBytes = static_cast<UINT32>(sound.size());
  buffer.pAudioData = sound.data();
  buffer.Flags = XAUDIO2_END_OF_STREAM;
  Check(voice->SetVolume(volume_ * master_volume_));
  Check(voice->SubmitSourceBuffer(&buffer));
  Check(voice->Start());
  next_voice_ = (index + 1) % voices_.size();
}

void KeyboardBridge::ReadInput(LPARAM lparam) {
  RAWINPUT input{};
  UINT size = sizeof(input);
  if (GetRawInputData(reinterpret_cast<HRAWINPUT>(lparam), RID_INPUT, &input, &size, sizeof(RAWINPUTHEADER)) == static_cast<UINT>(-1) ||
      input.header.dwType != RIM_TYPEKEYBOARD) return;
  const auto& key = input.data.keyboard;
  if (key.VKey == 255 || key.MakeCode == 0xFF) return;
  // Как и macOS keyDown, не озвучиваем отдельные изменения модификаторов.
  if (key.VKey == VK_SHIFT || key.VKey == VK_CONTROL || key.VKey == VK_MENU ||
      key.VKey == VK_LWIN || key.VKey == VK_RWIN || key.VKey == VK_CAPITAL) return;
  const int code = key.MakeCode | ((key.Flags & (RI_KEY_E0 | RI_KEY_E1)) << 8);
  const auto identity = std::make_pair(input.header.hDevice, code);
  if (key.Flags & RI_KEY_BREAK) { held_.erase(identity); return; }
  if (!held_.insert(identity).second) return;
  ++received_keys_;
  if (statistics_active_ && allowed_) ++statistics_keys_;
  if (!enabled_ || !allowed_) return;
  const int group = key.VKey == VK_SPACE ? 1 : key.VKey == VK_RETURN ? 2 :
      (key.VKey == VK_BACK || key.VKey == VK_DELETE) ? 3 : 0;
  try { Play(group); }
  catch (const std::exception& error) {
    enabled_ = false;
    error_ = error.what();
    DestroyAudio();
  }
}

void KeyboardBridge::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_INPUT && listening_) ReadInput(lparam);
  if (message == WM_INPUT_DEVICE_CHANGE && wparam == GIDC_REMOVAL) {
    const auto device = reinterpret_cast<HANDLE>(lparam);
    for (auto it = held_.begin(); it != held_.end();) {
      if (it->first == device) it = held_.erase(it); else ++it;
    }
  }
  if ((message == WM_POWERBROADCAST && wparam == PBT_APMSUSPEND) ||
      (message == WM_WTSSESSION_CHANGE && wparam == WTS_SESSION_LOCK) || message == kWaloneOutputChanged) {
    allowed_ = false;
    if (lifecycle_sink_) lifecycle_sink_->Success(Value(Map{{Value("reason"), Value("interruption")}}));
    held_.clear();
    DestroyAudio();
  }
}

void KeyboardBridge::Shutdown() {
  if (listening_) {
    RAWINPUTDEVICE keyboard{0x01, 0x06, RIDEV_REMOVE, nullptr};
    RegisterRawInputDevices(&keyboard, 1, sizeof(keyboard));
  }
  listening_ = false;
  statistics_active_ = false;
  enabled_ = false;
  held_.clear();
  DestroyAudio();
}
