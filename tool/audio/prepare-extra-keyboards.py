#!/usr/bin/env python3
"""Rebuild additional model clips from bundled originals, downloading only missing files.

Source URLs, licenses, SHA-256 and explicit clip ranges live in extra-keyboards.json.
Requires ffmpeg; the application itself uses only the resulting bundled WAV files.
"""
import array
import hashlib
import json
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1] / 'resource_sources'


def prepare():
    for pack in json.loads((ROOT / 'extra-keyboards.json').read_text()):
        destination = ROOT / pack['id']
        originals = destination / 'originals'
        originals.mkdir(parents=True, exist_ok=True)
        decoded = {}
        for source in pack['files']:
            path = originals / source['file']
            if not path.exists():
                path.write_bytes(subprocess.check_output([
                    'curl', '-L', '--fail', '--silent', '--show-error', '--max-time', '60', source['url']]))
            if hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
                raise ValueError(f'Source checksum mismatch: {path}')
            decoded[source['file']] = array.array('h', subprocess.check_output([
                'ffmpeg', '-v', 'error', '-i', str(path), '-f', 's16le', '-ac', '1', '-ar', '48000', '-']))
        for name, timing in pack['clips'].items():
            pcm = decoded[timing['file']]
            start = round(timing['start'] * 48000)
            end = round(timing.get('end', len(pcm) / 48000) * 48000)
            if not 0 <= start < end <= len(pcm):
                raise ValueError(f'Invalid clip range: {pack["id"]}/{name}')
            clip = pcm[start:end]
            peak = max(map(abs, clip))
            if peak == 0 or len(clip) > 48000:
                raise ValueError(f'Empty or oversized clip: {pack["id"]}/{name}')
            onset = next(i for i, value in enumerate(clip) if abs(value) > peak * 0.015)
            clip = clip[max(0, onset - 48):]
            for i in range(len(clip)):
                fade = min(1, i / 48, (len(clip) - 1 - i) / 192)
                clip[i] = round(clip[i] * (0.65 * 32767 / peak) * fade)
            with wave.open(str(destination / f'{name}.wav'), 'wb') as output:
                output.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
                output.writeframes(clip.tobytes())
        print(f'{pack["id"]}: {len(pack["clips"])} PCM recordings prepared')


if __name__ == '__main__':
    prepare()
