#!/usr/bin/env python3
"""Rebuild bundled PCM clips from a pinned MIT-licensed Mechvibes revision.
Requires ffmpeg; downloads source recordings only when explicitly run.
"""
import array
import json
from pathlib import Path
import subprocess
import tempfile
import wave

REVISION = '326252a13e7bef4f1c35d08ef0189b5af6f8ba02'
BASE = f'https://raw.githubusercontent.com/hainguyents13/mechvibes/{REVISION}'
ROOT = Path(__file__).resolve().parents[1] / 'resource_sources'


def fetch(path):
    return subprocess.check_output(['curl', '-L', '--fail', '--silent', '--show-error', '--max-time', '60', f'{BASE}/{path}'])


ROOT.mkdir(parents=True, exist_ok=True)
(ROOT / 'Mechvibes-LICENSE.txt').write_bytes(fetch('LICENSE'))
for pack in ['brown', 'red']:
    source = f'src/audio/cherrymx-{pack}-pbt'
    config = json.loads(fetch(f'{source}/config.json'))
    destination = ROOT / pack
    destination.mkdir(exist_ok=True)
    originals = destination / 'originals'
    originals.mkdir(exist_ok=True)
    (originals / 'config.json').write_text(json.dumps(config, indent=2) + '\n')
    with tempfile.TemporaryDirectory() as temp:
        original = Path(temp) / 'sound.ogg'
        decoded = Path(temp) / 'sound.wav'
        original.write_bytes(fetch(f'{source}/sound.ogg'))
        (originals / 'sound.ogg').write_bytes(original.read_bytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(original), '-ac', '1', '-ar', '48000', '-c:a', 'pcm_s16le', str(decoded)], check=True)
        with wave.open(str(decoded)) as recording:
            pcm = array.array('h', recording.readframes(recording.getnframes()))
    # Six ordinary keys plus their actual Space, Enter and Backspace recordings.
    for name, key in [(f'key{i}', key) for i, key in enumerate([30, 31, 32, 33, 34, 35])] + [('space', 57), ('enter', 28), ('backspace', 14)]:
        start, duration = config['defines'][str(key)]
        clip = pcm[round(start * 48):round((start + duration) * 48)]
        peak = max(abs(value) for value in clip)
        assert peak > 0, (pack, name)
        onset = next(i for i, value in enumerate(clip) if abs(value) > peak * 0.015)
        clip = clip[max(0, onset - 48):]
        for i in range(len(clip)):
            fade = min(1, i / 48, (len(clip) - 1 - i) / 192)
            clip[i] = round(clip[i] * (0.65 * 32767 / peak) * fade)
        with wave.open(str(destination / f'{name}.wav'), 'wb') as output:
            output.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
            output.writeframes(clip.tobytes())
    print(f'{pack}: 9 PCM recordings prepared')
