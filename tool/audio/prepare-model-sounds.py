#!/usr/bin/env python3
"""Prepare bundled model recordings. Network and ffmpeg are build-time only."""
import array
from pathlib import Path
import subprocess
import tempfile
import wave

REVISION = '6785c7ac17b9f4db1f3d7f3d1d87a23067944517'
BASE = f'https://raw.githubusercontent.com/nathan-fiscaletti/keyboardsounds/{REVISION}'
ROOT = Path(__file__).resolve().parents[1] / 'resource_sources'
PACKS = {
    'apex-pro-tkl-v2': ['key1.wav', 'key3.wav', 'key4.wav', 'space.wav', 'enter.wav', 'key1.wav'],
    'logitech-g915-tkl-brown': [f'key-press-{i}.wav' for i in range(1, 6)] +
        ['space-press-1.wav', 'enter-press-1.wav', 'enter-press-1.wav'],
}


def fetch(path):
    return subprocess.check_output(['curl', '-L', '--fail', '--silent', '--show-error',
                                    '--max-time', '60', f'{BASE}/{path}'])


def main():
    (ROOT / 'KeyboardSounds-LICENSE.txt').write_bytes(fetch('LICENSE'))
    for pack, sources in PACKS.items():
        destination = ROOT / pack
        originals = destination / 'originals'
        originals.mkdir(parents=True, exist_ok=True)
        upstream = f'keyboardsounds/profiles/{pack}'
        (originals / 'profile.yaml').write_bytes(fetch(f'{upstream}/profile.yaml'))
        for source in dict.fromkeys(sources):
            (originals / source).write_bytes(fetch(f'{upstream}/{source}'))
        names = [f'key{i}' for i in range(len(sources) - 3)] + ['space', 'enter', 'backspace']
        for name, source in zip(names, sources):
            with tempfile.TemporaryDirectory() as temp:
                decoded = Path(temp) / 'decoded.wav'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(originals / source),
                                '-ac', '1', '-ar', '48000', '-c:a', 'pcm_s16le', str(decoded)], check=True)
                with wave.open(str(decoded)) as recording:
                    pcm = array.array('h', recording.readframes(recording.getnframes()))
            peak = max(abs(value) for value in pcm)
            assert peak > 0, (pack, source)
            onset = next(i for i, value in enumerate(pcm) if abs(value) > peak * 0.015)
            clip = pcm[max(0, onset - 48):]
            assert 0 < len(clip) <= 48000, (pack, source, len(clip))
            # G915 source press clips end while still resonating; taper that short tail.
            fade_out = 720 if pack == 'logitech-g915-tkl-brown' else 192
            for i in range(len(clip)):
                fade = min(1, i / 48, (len(clip) - 1 - i) / fade_out)
                clip[i] = round(clip[i] * (0.65 * 32767 / peak) * fade)
            with wave.open(str(destination / f'{name}.wav'), 'wb') as output:
                output.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
                output.writeframes(clip.tobytes())
        print(f'{pack}: {len(names)} PCM recordings prepared')


if __name__ == '__main__':
    main()
