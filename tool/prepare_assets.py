#!/usr/bin/env python3
"""Подготовка Flutter-ресурсов из локальных исходников проекта без сети."""
import json
import math
from pathlib import Path
import re
import shutil
import struct
import wave

APP = Path(__file__).resolve().parents[1]
SOURCE = APP / 'tool/resource_sources'
text = (APP / 'macos/Runner/KeyboardAudio.swift').read_text()
enum = text.split('    var id:')[0]
ids = {}
for names in re.findall(r'^    case (.+)$', enum, re.M):
    for name in names.split(', '):
        match = re.fullmatch(r'(\w+)(?: = "([\w-]+)")?', name)
        if not match:
            raise ValueError(f'Неизвестный формат case: {name}')
        ids[match[1]] = match[2] or match[1]
counts = dict(re.findall(r'case \.(\w+): return (\d+)', text.split('    var title:')[0]))
descriptions = re.findall(r'case \.(\w+): return \("([^"]+)", "([^"]+)", "([^"]+)"\)', text)
assert {name for name, *_ in descriptions} == set(ids), 'Каталог Swift изменился'
assets = APP / 'assets'
keyboards = assets / 'keyboards'
keyboards.mkdir(parents=True, exist_ok=True)
catalog = []
for name, title, detail, author in descriptions:
    pack_id = ids[name]
    key_count = int(counts.get(name, 6))
    target = keyboards / pack_id
    target.mkdir(exist_ok=True)
    for clip in [f'key{i}' for i in range(key_count)] + ['space', 'enter', 'backspace']:
        original = SOURCE / pack_id / f'{clip}.wav'
        with wave.open(str(original)) as audio:
            assert (audio.getnchannels(), audio.getframerate(), audio.getsampwidth()) == (1, 48000, 2)
            assert 0 < audio.getnframes() <= 48000
        shutil.copyfile(original, target / original.name)
    catalog.append(dict(id=pack_id, title=title, detail=detail, author=author, keyCount=key_count))
(assets / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
licenses = assets / 'licenses'
licenses.mkdir(exist_ok=True)
for filename in ['SOURCES.md', 'extra-keyboards.json', 'Mechvibes-LICENSE.txt', 'KeyboardSounds-LICENSE.txt', 'Bucklespring-LICENSE.txt', 'CC0-1.0.txt', 'CC-BY-3.0.txt', 'CC-BY-4.0.txt']:
    shutil.copyfile(SOURCE / filename, licenses / filename)
# Flutter включает только явно перечисленные подпапки ресурсов.
pubspec = APP / 'pubspec.yaml'
base = pubspec.read_text().split('  # BEGIN KEYBOARD ASSETS')[0]
atmosphere = assets / 'atmosphere'
atmosphere.mkdir(exist_ok=True)
for source in (SOURCE / 'atmosphere').glob('*.wav'):
    shutil.copyfile(source, atmosphere / source.name)
shutil.copyfile(SOURCE / 'atmosphere/sources.json', licenses / 'atmosphere-sources.json')
# Скрипты VK имеют собственные JS-исходники внутри проекта.
imports = assets / 'import'
imports.mkdir(exist_ok=True)
for source in (SOURCE / 'import').glob('*.js'):
    shutil.copyfile(source, imports / source.name)
# Собственные сигналы: нисходящий после работы, восходящий после отдыха.
timer = assets / 'timer'
timer.mkdir(exist_ok=True)
for phase, notes in [('work', [880, 660, 440]), ('rest', [440, 660, 880])]:
    frames = bytearray()
    for frequency in notes:
        for sample in range(19200):
            time = sample / 48000
            envelope = min(time / 0.015, 1) * max(0, 1 - time / 0.36) ** 2
            value = int(0.4 * 32767 * envelope * math.sin(2 * math.pi * frequency * time))
            frames.extend(struct.pack('<h', value))
    with wave.open(str(timer / f'{phase}-complete.wav'), 'wb') as audio:
        audio.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        audio.writeframes(frames)
entries = ['assets/catalog.json', 'assets/licenses/', 'assets/atmosphere/', 'assets/import/', 'assets/timer/'] + [f'assets/keyboards/{p["id"]}/' for p in catalog]
pubspec.write_text(base + '  # BEGIN KEYBOARD ASSETS — генерируется tool/prepare_assets.py\n  assets:\n' + ''.join(f'    - {entry}\n' for entry in entries))
print(f'Подготовлено {len(catalog)} наборов, {sum(p["keyCount"] + 3 for p in catalog)} WAV; лицензии сохранены.')
