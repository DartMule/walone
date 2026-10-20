#!/usr/bin/env python3
"""Validate bundled ambience PCM, peaks, loop edges and faded event boundaries."""
import array
import json
from pathlib import Path
import wave

ROOT = Path(__file__).resolve().parents[1] / 'resource_sources/atmosphere'
errors = []
checked = 0
for source in json.loads((ROOT / 'sources.json').read_text()):
    names = [f"{source['id']}-{i}" for i in range(3)] if source.get('events') else [source['id']]
    for name in names:
        with wave.open(str(ROOT / f'{name}.wav')) as audio:
            assert audio.getnchannels() == 2 and audio.getsampwidth() == 2 and audio.getframerate() == 24000, name
            pcm = array.array('h', audio.readframes(audio.getnframes()))
            assert audio.getnframes() >= 24000, name
        peak = max(map(abs, pcm)) / 32768
        rms = (sum(x*x for x in pcm)/len(pcm)) ** 0.5 / 32768
        edge = max(abs(pcm[-2]-pcm[0]), abs(pcm[-1]-pcm[1])) / 32768
        if not 0.001 < rms < 0.15 or not 0 < peak < 0.4:
            errors.append(f'{name}: invalid level RMS={rms:.4f}, peak={peak:.4f}')
        # A noise edge is a normal adjacent noise sample. Recorded loops should be much closer.
        limit = 0.08 if source.get('generated') else 0.015
        if edge > limit:
            errors.append(f'{name}: discontinuous edge {edge:.4f}')
        if source.get('events') and any(pcm[i] != 0 for i in [0, 1, -2, -1]):
            errors.append(f'{name}: event edges are not silent')
        if source.get('events'):
            if len(pcm) / (2 * 24000) < 9:
                errors.append(f'{name}: event was not time-stretched')
            if max(map(abs, pcm[-12000:])) / 32768 > 0.003:
                errors.append(f'{name}: last quarter-second does not fade gently')
        checked += 1
print(f'{checked} ambient clips checked; {len(errors)} failures')
for error in errors:
    print(error)
raise SystemExit(bool(errors))
