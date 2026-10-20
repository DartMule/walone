#include "../windows/runner/keyboard_wav.h"
#include <iostream>

int main(int argc, char** argv) {
  if (argc != 2) return 64;
  size_t checked = 0;
  for (const auto& pack : std::filesystem::directory_iterator(argv[1])) {
    if (!pack.is_directory()) continue;
    for (const auto& file : std::filesystem::directory_iterator(pack.path())) {
      if (file.path().extension() != ".wav") continue;
      const auto pcm = ReadKeyboardWav(file.path());
      if (pcm.empty()) return 1;
      ++checked;
    }
  }
  if (checked != 172) return 1;
  const auto broken = std::filesystem::temp_directory_path() / "walone-invalid-test.wav";
  { std::ofstream file(broken, std::ios::binary); file << "RIFFbroken"; }
  bool rejected = false;
  try { ReadKeyboardWav(broken); }
  catch (const std::runtime_error&) { rejected = true; }
  std::filesystem::remove(broken);
  if (!rejected) return 1;
  std::cout << "PCM16 WAV: " << checked << "; повреждённый WAV отклонён\n";
}
