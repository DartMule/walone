#ifndef WALONE_KEYBOARD_BRIDGE_H_
#define WALONE_KEYBOARD_BRIDGE_H_

#include <windows.h>
#include <xaudio2.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include "audio_output_observer.h"

#include <array>
#include <atomic>
#include <filesystem>
#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

class KeyboardBridge final : public IXAudio2EngineCallback {
 public:
  KeyboardBridge(HWND window, flutter::BinaryMessenger* messenger);
  ~KeyboardBridge();
  void HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

  void __stdcall OnProcessingPassStart() override {}
  void __stdcall OnProcessingPassEnd() override {}
  void __stdcall OnCriticalError(HRESULT error) override { audio_error_.store(error); }

 private:
  flutter::EncodableValue Status();
  void Initialize();
  void Shutdown();
  void SelectPack(const std::string& id, int key_count);
  void StartAudio();
  void StopVoices();
  void DestroyAudio();
  void Play(int group);
  void ReadInput(LPARAM lparam);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> lifecycle_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> lifecycle_sink_;
  AudioOutputObserver* output_observer_ = nullptr;
  float master_volume_ = 0.7f;
  bool allowed_ = true;
  bool listening_ = false;
  bool enabled_ = false;
  float volume_ = 0.35f;
  int64_t received_keys_ = 0;
  bool statistics_active_ = false;
  int64_t statistics_keys_ = 0;
  std::string error_;
  std::string pack_;
  size_t key_count_ = 0;
  size_t variation_ = 0;
  size_t next_voice_ = 0;
  std::set<std::pair<HANDLE, int>> held_;
  std::vector<std::vector<uint8_t>> sounds_;
  IXAudio2* engine_ = nullptr;
  IXAudio2MasteringVoice* master_ = nullptr;
  std::array<IXAudio2SourceVoice*, 24> voices_{};
  std::atomic<HRESULT> audio_error_{S_OK};
};

#endif
