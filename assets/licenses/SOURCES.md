# Keyboard recordings

Source: https://github.com/hainguyents13/mechvibes
Pinned revision: `326252a13e7bef4f1c35d08ef0189b5af6f8ba02`.
Original directories: `src/audio/cherrymx-brown-pbt`, `src/audio/cherrymx-red-pbt`.
Copyright (c) 2021 Hai Nguyen. Distributed under the repository MIT license,
reproduced in `Mechvibes-LICENSE.txt` alongside these recordings.

Walone extracts the six ordinary keys A/S/D/F/G/H and Space/Enter/Backspace
using the original pack's millisecond map, converts to mono 48 kHz PCM,
trims leading silence, normalizes peaks to 0.65 and fades clip edges.
No synthetic sound or runtime network request is used.
Reproduce with `python3 tool/audio/prepare-keyboard-sounds.py` (requires ffmpeg).

## Keyboard model recordings

Source: https://github.com/nathan-fiscaletti/keyboardsounds
Pinned revision: `6785c7ac17b9f4db1f3d7f3d1d87a23067944517`.
These recordings are distributed under the upstream GNU GPL version 3;
the full license is in `KeyboardSounds-LICENSE.txt`.

- `apex-pro-tkl-v2`: SteelSeries Apex Pro TKL v2, recorded by Akira.
  Original directory: `keyboardsounds/profiles/apex-pro-tkl-v2`.
  Three ordinary key recordings, Space and Enter. Backspace uses `key1.wav`,
  since the source does not contain a dedicated Backspace recording.
- `logitech-g915-tkl-brown`: Logitech G915 TKL with Brown switches,
  recorded by Keyboard Sounds.
  Original directory: `keyboardsounds/profiles/logitech-g915-tkl-brown`.
  Five ordinary key recordings, first Space and first Enter press recordings.
  Backspace uses Enter, matching the original profile's mapping.

Original WAV files used and the unmodified upstream profile are included in
each model's `originals/` directory. On 2026-10-16 Walone converted these
recordings to mono 48 kHz PCM, trimmed leading silence, normalized peaks to
0.65 and faded clip edges. These derived recordings retain GPL-3.0 licensing.
No program code from Keyboard Sounds is incorporated.
Reproduce with `python3 tool/audio/prepare-model-sounds.py` (network and ffmpeg
needed only for preparation). Both models are fully bundled for offline use.

## Additional keyboard models — 2026-10-16

The catalog now contains 18 model profiles, plus the two original switch-only
profiles. All audio is bundled; the application makes no network requests.
Names identify the model stated by the recording's author, not an endorsement
by its manufacturer. Recording equipment, room and switch configuration affect
the result; these are samples of particular keyboards, not every configuration.

| Model | Recording author and source | Recording license |
| --- | --- | --- |
| IBM Model M Space Saver | [Ico Doornekamp / Bucklespring](https://github.com/zevv/bucklespring/tree/43274ed8bca545fde585d73d89086bf9ae5ed1d0) | GPL-2.0 |
| HHKB Professional Hybrid, Topre 45 g | [grcekh — Keyboard Typing 7](https://freesound.org/people/grcekh/sounds/546164/) | CC0 1.0 |
| WhiteFox, Hako Violet | [grcekh — Keyboard Typing 10](https://freesound.org/people/grcekh/sounds/546167/) | CC0 1.0 |
| Keychron K10, linear | [Sadiquecat — individual keys](https://freesound.org/people/Sadiquecat/sounds/789628/), [Space](https://freesound.org/people/Sadiquecat/sounds/789630/) | CC0 1.0 |
| Dell Latitude D510 | [justamudkip — Typing on Laptop Keyboard #3 (Slow)](https://freesound.org/people/justamudkip/sounds/854746/) | CC0 1.0 |
| Razer BlackWidow Ultimate | [yottasounds — Computer Keyboard - typing sounds.wav](https://freesound.org/people/yottasounds/sounds/380135/) | CC0 1.0 |
| Razer BlackWidow (2013) | [newagesoup — MECH-KEYBOARD-02.wav](https://freesound.org/people/newagesoup/sounds/348238/), [MECH-KEYBOARD-01.wav](https://freesound.org/people/newagesoup/sounds/348239/) | CC0 1.0 |
| Razer BlackWidow Tournament Edition | [WaveAdventurer — Mechanical keyboard typing](https://freesound.org/people/WaveAdventurer/sounds/702236/) | CC BY 4.0 |
| Corsair K70 (2016) | [luutoo — keyboard typing (1 sentence)](https://freesound.org/people/luutoo/sounds/567920/) | CC BY 3.0 |
| Corsair K95, Cherry MX Red | [handygaber — Keyboard clicking typing Cherry Red Mechanical](https://freesound.org/people/handygaber/sounds/499773/) | CC0 1.0 |
| Corsair K95 RGB Platinum, Cherry MX Brown | [NickTHH — Cherry MX Brown Mechanical Keyboard Sound.mp3](https://freesound.org/people/NickTHH/sounds/432432/) | CC0 1.0 |
| Ducky × Varmilo Miya, Brown | [eclectic-kitty — Mechanical Keyboard Typing](https://freesound.org/people/eclectic-kitty/sounds/757638/) | CC0 1.0 |
| Apple IIe | [makenoisemusic — Apple IIe Typing Morphagene Reel.wav](https://freesound.org/people/makenoisemusic/sounds/577849/) | CC0 1.0 |
| Apple Pro Keyboard | [BrodieSound — Typing.wav](https://freesound.org/people/BrodieSound/sounds/349377/) | CC0 1.0 |
| Apple Aluminum Keyboard | [Tomlija — tastatura.aif](https://freesound.org/people/Tomlija/sounds/75372/) | CC BY 3.0 |
| Microsoft Internet Keyboard Pro RT9420 | [PanosA — Typing on Microsoft keyboard.wav](https://freesound.org/people/PanosA/sounds/546369/) | CC0 1.0 |

License texts are included locally as `Bucklespring-LICENSE.txt`,
`CC0-1.0.txt`, `CC-BY-3.0.txt` and `CC-BY-4.0.txt`. The Creative Commons texts
also identify their canonical URLs. Attribution for the CC BY recordings is
given in the table above and in `extra-keyboards.json`.

Freesound originals here are its publicly served MP3 previews, retained in
each model's `originals/` folder, not claims of lossless source quality.
`extra-keyboards.json` records each source URL, author, title, license,
SHA-256 and exact extraction ranges. Walone's modifications on 2026-10-16:
extract short keystroke fragments, convert to mono 48 kHz PCM, trim leading
silence, normalize each fragment to peak 0.65 and fade clip edges. No pitch
shifting, synthetic replacements or audio from another model is used.

IBM uses six distinct letter press recordings (A/S/D/F/G/H), Space, Enter and
Backspace. Keychron uses six individual key samples and its separate Space
recording; Enter/Backspace use ordinary samples. Razer (2013) has two samples;
the other Freesound models have six. Except Keychron Space, special-key sounds
for Freesound models are ordinary samples from the same recording because
their exact key identities are not established. The cards disclose this.

Rebuild these 16 additions using `python3 tool/audio/prepare-extra-keyboards.py`.
With the bundled originals this needs ffmpeg but no network; missing originals
are fetched from the manifest and checked against their pinned SHA-256.
The conversion script is `tool/audio/prepare-extra-keyboards.py`. No code from the upstream applications
is incorporated into Walone.

### Slicing correction — 2026-10-16

The first Apple Pro Keyboard extraction mistakenly included three fragments
dominated by low-frequency recording rumble rather than key attacks. All six
Apple Pro ranges were reselected from distinct, clear attacks in the same
BrodieSound recording. No equalization, pitch shifting or substituted model
was used. Several Corsair K95 RGB Platinum ranges were also reselected to
avoid tightly overlapping keystrokes.

Truncated tails were extended to quieter boundaries in HHKB, WhiteFox,
Razer Tournament Edition, Corsair K70/K95 Red, Ducky Miya, Apple IIe and
Apple Aluminum. Ordinary-key fallbacks were updated along with their source
fragments. Exact revised ranges are in `extra-keyboards.json`; original files,
authors and licenses remain as listed above.

`python3 tool/audio/check-keyboard-clips.py` checks the 140 additional catalog
clips for cuts through an ongoing sound and fragments dominated by sub-150 Hz
rumble. This is a regression check for the observed slicing mistakes, not
a guarantee of subjective audio quality or exact physical key identification.

### Full catalog audit — 2026-10-16

The audit now covers all 20 packs and 172 playback WAV files, including the
original Brown/Red profiles, Apex and G915. Mechvibes source recordings and
their key maps are retained in `brown/originals/` and `red/originals/` from the
same pinned revision stated above. The preparation script retains these
source files on regeneration. No change was needed to Brown/Red or Apex audio.

Further corrections: reselected Corsair K70 and Apple IIe clips; moved the
start/end boundaries of Razer Tournament Edition, Ducky Miya, Microsoft
Internet Keyboard Pro and Corsair K95 RGB Platinum clips to quieter regions.
Apple IIe replacements contain clearer keystroke attacks rather than the
bass-heavy late fragments. All come from their existing listed recordings.
G915's original press recordings already end while still resonating; their
final fade was lengthened from 4 ms to 15 ms without synthesizing a new tail.

The expanded check also tests the signal before the cut, the final fade of
the actual playback WAV, the complete file inventory, PCM format, clipping
and zero-valued edges. Generate per-file measurements with
`python3 tool/audio/check-keyboard-clips.py --report build/catalog-audio-quality.json`.
The report is a local build artifact, not a checked-in source file. It is an instrumental check, not a listening
review: it cannot rule out every subjective oddity or identify every real
key solely from a typing recording.

## Атмосфера работы

Все фоновые звуки встроены и воспроизводятся без сети. Записи получены из
[Blanket](https://github.com/rafaelmardojai/blanket/blob/775f2a767230a9681850d1b1e085be58656f1382/SOUNDS_LICENSING.md)
(фиксированная ревизия `775f2a767230a9681850d1b1e085be58656f1382`),
кроме чаек. Авторские права на записи принадлежат перечисленным авторам;
лицензия программы Blanket не заменяет отдельные лицензии этих записей.

| Элемент | Автор | Источник | Лицензия |
| --- | --- | --- | --- |
| Дождь | alex36917; подготовка Porrumentzio | [Rain](https://freesound.org/people/alex36917/sounds/524605/) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Океан | Luftrum; подготовка Porrumentzio | [Waves](https://freesound.org/people/Luftrum/sounds/48412/) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Поезд | SDLx | [Train](https://freesound.org/people/SDLx/sounds/259988/) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Кафе | stephan | [Restaurant Ambiance](https://soundbible.com/1664-Restaurant-Ambiance.html) | Public Domain |
| Ветер | felix.blume; подготовка Porrumentzio | [Wind](https://freesound.org/people/felix.blume/sounds/217506/) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Птицы | kvgarlic; подготовка Porrumentzio | [Birds](https://freesound.org/people/kvgarlic/sounds/156826/) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Чайки | squashy555 | [Seagull on beach](https://freesound.org/people/squashy555/sounds/353416/) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Белый, розовый и коричневый шум | Walone contributors | Синтез ffmpeg anoisesrc, seed 20261016 | CC0 1.0 |

Изменения Walone: преобразование в стерео PCM 24 кГц, выравнивание уровней
с запасом для микширования, обрезка длинных записей до 48 секунд и перекрытие
краёв непрерывных дорожек. Для птиц и чаек подготовлены три фрагмента
с плавным входом за 1 секунду и затуханием за 3 секунды. Эти фрагменты
замедлены до 85% темпа без изменения высоты, их целевой RMS снижен с 0,055
до 0,04. Между фрагментами — нерегулярные паузы 12–36 секунд.
Чайки подготовлены из общедоступного MP3-превью Freesound.

Точные URL загрузок, SHA-256 исходных файлов и авторство:
`atmosphere/sources.json`. Подготовка: `tool/audio/prepare-atmosphere.py`. Тексты CC BY 3.0, CC BY 4.0
и CC0 находятся рядом с этим документом. Сгенерированные записи шумов
переданы авторами Walone в общественное достояние по CC0 1.0.
