#ifndef RUNNER_MUSIC_WAVEFORM_H_
#define RUNNER_MUSIC_WAVEFORM_H_

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

// Декодирование не занимает UI-поток; в памяти остаётся только RMS каждые 20 мс.
class MusicWaveformReader {
 public:
  struct Batch {
    std::vector<double> levels;
    bool done = false;
    bool failed = false;
  };
  explicit MusicWaveformReader(const std::wstring& path);
  ~MusicWaveformReader();
  Batch Read();

 private:
  struct State {
    std::atomic<bool> cancelled{false};
    std::mutex mutex;
    Batch batch;
  };
  static void Decode(const std::shared_ptr<State>& state, const std::wstring& path);
  std::shared_ptr<State> state_;
};

#endif
