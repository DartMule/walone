#ifndef WALONE_KEYBOARD_WAV_H_
#define WALONE_KEYBOARD_WAV_H_

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <vector>

// Только подготовленные короткие PCM16 mono 48 kHz; неизвестные WAV отклоняются.
inline std::vector<uint8_t> ReadKeyboardWav(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) throw std::runtime_error("Не удалось открыть WAV");
  stream.seekg(0, std::ios::end);
  const auto length = stream.tellg();
  if (length < 44 || length > 200000) throw std::runtime_error("Недопустимый размер WAV");
  stream.seekg(0);
  const std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(stream)), {});
  const auto u16 = [&](size_t i) -> uint16_t {
    return static_cast<uint16_t>(bytes.at(i) | (bytes.at(i + 1) << 8));
  };
  const auto u32 = [&](size_t i) -> uint32_t {
    return static_cast<uint32_t>(u16(i)) | (static_cast<uint32_t>(u16(i + 2)) << 16);
  };
  const auto tag = [&](size_t i, const char* text) {
    return bytes.at(i) == text[0] && bytes.at(i + 1) == text[1] &&
           bytes.at(i + 2) == text[2] && bytes.at(i + 3) == text[3];
  };
  if (!tag(0, "RIFF") || !tag(8, "WAVE") || u32(4) != bytes.size() - 8)
    throw std::runtime_error("Повреждён заголовок WAV");
  bool valid_format = false;
  std::vector<uint8_t> pcm;
  for (size_t offset = 12; offset + 8 <= bytes.size();) {
    const size_t size = u32(offset + 4);
    const size_t start = offset + 8;
    if (size > bytes.size() - start) throw std::runtime_error("Обрезанный WAV");
    if (tag(offset, "fmt ")) {
      if (size < 16 || u16(start) != 1 || u16(start + 2) != 1 ||
          u32(start + 4) != 48000 || u32(start + 8) != 96000 ||
          u16(start + 12) != 2 || u16(start + 14) != 16)
        throw std::runtime_error("Ожидался PCM16 mono 48 kHz");
      valid_format = true;
    } else if (tag(offset, "data")) {
      if (size == 0 || size > 96000 || size % 2 != 0 || !pcm.empty())
        throw std::runtime_error("Недопустимые данные WAV");
      pcm.assign(bytes.begin() + start, bytes.begin() + start + size);
    }
    offset = start + size + (size % 2);
  }
  if (!valid_format || pcm.empty()) throw std::runtime_error("Нет звука в WAV");
  return pcm;
}

#endif
