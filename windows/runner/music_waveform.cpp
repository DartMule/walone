#include "music_waveform.h"

#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>
#include <thread>

using Microsoft::WRL::ComPtr;

namespace {
void Check(HRESULT result) {
  if (FAILED(result)) throw std::runtime_error("Не удалось декодировать звук");
}
}

MusicWaveformReader::MusicWaveformReader(const std::wstring& path)
    : state_(std::make_shared<State>()) {
  // Поток владеет только State, не мостом Flutter. Отмена не задерживает окно.
  std::thread([state = state_, path]() { Decode(state, path); }).detach();
}

MusicWaveformReader::~MusicWaveformReader() { state_->cancelled = true; }

MusicWaveformReader::Batch MusicWaveformReader::Read() {
  std::lock_guard<std::mutex> lock(state_->mutex);
  Batch result;
  result.levels.swap(state_->batch.levels);
  result.done = state_->batch.done;
  result.failed = state_->batch.failed;
  return result;
}

void MusicWaveformReader::Decode(const std::shared_ptr<State>& state,
                                 const std::wstring& path) {
  const auto com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const auto mf = SUCCEEDED(com) ? MFStartup(MF_VERSION, MFSTARTUP_LITE) : com;
  bool failed = false;
  try {
    Check(mf);
    ComPtr<IMFSourceReader> reader;
    Check(MFCreateSourceReaderFromURL(path.c_str(), nullptr, &reader));
    Check(reader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS, FALSE));
    Check(reader->SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE));
    ComPtr<IMFMediaType> type;
    Check(MFCreateMediaType(&type));
    Check(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio));
    Check(type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float));
    Check(reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, nullptr, type.Get()));
    Check(reader->GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, &type));
    const UINT32 rate = MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_SAMPLES_PER_SECOND, 0);
    const UINT32 channels = MFGetAttributeUINT32(type.Get(), MF_MT_AUDIO_NUM_CHANNELS, 0);
    if (rate < 50 || rate > 384000 || channels == 0 || channels > 32)
      throw std::runtime_error("Некорректный формат звука");
    size_t block = static_cast<size_t>(rate / 50) * channels;
    size_t count = 0;
    size_t total = 0;
    double energy = 0;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::minutes(2);
    bool end = false;
    while (!state->cancelled && total < 21600 * 50 &&
           std::chrono::steady_clock::now() < deadline) {
      DWORD flags = 0;
      ComPtr<IMFSample> sample;
      Check(reader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, nullptr,
                               &flags, nullptr, &sample));
      if (flags & (MF_SOURCE_READERF_ERROR | MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED))
        throw std::runtime_error("Изменился формат звука");
      if (sample) {
        ComPtr<IMFMediaBuffer> buffer;
        Check(sample->ConvertToContiguousBuffer(&buffer));
        BYTE* bytes = nullptr;
        DWORD length = 0;
        std::vector<double> levels;
        Check(buffer->Lock(&bytes, nullptr, &length));
        const auto* pcm = reinterpret_cast<const float*>(bytes);
        for (size_t i = 0; i < length / sizeof(float) && total < 21600 * 50; ++i) {
          const double value = std::isfinite(pcm[i]) ? pcm[i] : 0;
          energy += value * value;
          if (++count == block) {
            levels.push_back(std::clamp(std::sqrt(energy / static_cast<double>(count)), 0.0, 1.0));
            ++total;
            // Границы целых кадров без накопления ошибки для частот вроде 11025 Гц.
            block = ((total + 1) * rate / 50 - total * rate / 50) * channels;
            count = 0;
            energy = 0;
          }
        }
        buffer->Unlock();
        std::lock_guard<std::mutex> lock(state->mutex);
        state->batch.levels.insert(state->batch.levels.end(), levels.begin(), levels.end());
      }
      if (flags & MF_SOURCE_READERF_ENDOFSTREAM) {
        end = true;
        break;
      }
    }
    if (end && count > 0 && !state->cancelled) {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->batch.levels.push_back(std::clamp(std::sqrt(energy / static_cast<double>(count)), 0.0, 1.0));
    }
  } catch (...) {
    failed = true;
  }
  if (SUCCEEDED(mf)) MFShutdown();
  if (SUCCEEDED(com)) CoUninitialize();
  std::lock_guard<std::mutex> lock(state->mutex);
  state->batch.failed = failed;
  state->batch.done = true;
  if (failed || state->cancelled) state->batch.levels.clear();
}
