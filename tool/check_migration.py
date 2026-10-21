#!/usr/bin/env python3
"""Проверка автономности проекта и сохранности перенесённых ресурсов, без сети."""
import hashlib
import json
from pathlib import Path
import re

APP = Path(__file__).resolve().parents[1]
SOURCE = APP / 'tool/resource_sources'
ASSETS = APP / 'assets'

catalog = json.loads((ASSETS / 'catalog.json').read_text(encoding='utf-8'))
assert len(catalog) == 20
expected = set()
for pack in catalog:
    for name in [f'key{i}' for i in range(pack['keyCount'])] + ['space', 'enter', 'backspace']:
        relative = Path(pack['id']) / f'{name}.wav'
        expected.add(relative)
        assert (ASSETS / 'keyboards' / relative).read_bytes() == (SOURCE / relative).read_bytes(), relative
assert {p.relative_to(ASSETS / 'keyboards') for p in (ASSETS / 'keyboards').rglob('*.wav')} == expected
assert len(expected) == 172
ambient = list((SOURCE / 'atmosphere').glob('*.wav'))
assert len(ambient) == 14
for path in ambient:
    assert path.read_bytes() == (ASSETS / 'atmosphere' / path.name).read_bytes(), path.name
for path in (ASSETS / 'licenses').iterdir():
    original = SOURCE / path.name
    if path.name == 'atmosphere-sources.json':
        original = SOURCE / 'atmosphere/sources.json'
    assert path.read_bytes() == original.read_bytes(), path.name
for name in ['CC0-1.0.txt', 'CC-BY-3.0.txt', 'CC-BY-4.0.txt']:
    assert (ASSETS / 'licenses' / name).stat().st_size > 0
for name in ['catalogScript.js', 'resolveScript.js']:
    assert (ASSETS / 'import' / name).read_bytes() == (SOURCE / 'import' / name).read_bytes(), name
# Эталон переноса хранится в самом проекте, а не в архиве старого приложения.
baseline = json.loads((SOURCE / 'bundled-sha256.json').read_text(encoding='utf-8'))
actual = {p.relative_to(ASSETS).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in ASSETS.rglob('*') if p.is_file() and not p.name.startswith('.')}
assert actual == baseline, 'Состав или содержимое ресурсов изменились относительно эталона'
project = (APP / 'macos/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
for path in re.findall(r'path = ([^;]+\.swift);', project):
    assert not Path(path).is_absolute() and '..' not in Path(path).parts, path
for name in ['KeyboardAudio.swift', 'AudioOutputMonitor.swift', 'SensorStream.swift',
             'ImpactEstimator.swift', 'IntensityCalibration.swift']:
    assert f'path = {name};' in project, name
    assert (APP / 'macos/Runner' / name).is_file(), name
assert (APP / 'tool/sensor-probe.c').is_file()
print('migration_resources=ok: standalone native code, 20 packs, 172 keyboard WAV, 14 atmosphere WAV, licenses and VK scripts unchanged')
