#!/usr/bin/env python3
"""Prepare offline ambience. Requires ffmpeg; downloads only when --download is set.

Loop tails overlap their heads by up to one second (linear crossfade). Events use
pitch-preserving time stretching and long faded tails. Noise uses deterministic seeds.
"""
import argparse
import array
import hashlib
import json
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'tool/resource_sources/atmosphere'
MANIFEST = OUTPUT / 'sources.json'
RATE = 24000


def run(*args):
    return subprocess.check_output(args)


def write(name, pcm):
    with wave.open(str(OUTPUT / f'{name}.wav'), 'wb') as target:
        target.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        target.writeframes(pcm.tobytes())


def prepare(source_dir, download, only=None):
    manifest = json.loads(MANIFEST.read_text())
    for entry in manifest:
        if only and entry['id'] not in only:
            continue
        if entry.get('generated'):
            pcm = array.array('f', run('ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                f"anoisesrc=color={entry['id']}:seed=20261016:sample_rate={RATE}:duration=32",
                '-ac', '2', '-f', 'f32le', '-'))
        else:
            source = source_dir / entry['file']
            if not source.exists() and download:
                source.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run(['curl', '-LfsS', '--max-time', '90', entry['download'], '-o', str(source)], check=True)
            actual = hashlib.sha256(source.read_bytes()).hexdigest()
            if actual != entry['sha256']:
                raise ValueError(f"Checksum mismatch: {source}")
            tempo = ['-af', 'atempo=0.85'] if entry.get('events') else []
            pcm = array.array('f', run('ffmpeg', '-v', 'error', '-i', str(source), '-t', '48', *tempo, '-ac', '2', '-ar', str(RATE), '-f', 'f32le', '-'))
        # Consistent RMS, with peak headroom for layered playback.
        rms = (sum(x*x for x in pcm) / len(pcm)) ** 0.5
        gain = min(0.085 / max(rms, 1e-9), 0.38 / max(map(abs, pcm)))
        pcm = array.array('f', (x * gain for x in pcm))
        if entry.get('events'):
            frames = len(pcm) // 2
            length = min(round(RATE * 8 / 0.85), frames // 3)
            for variant in range(3):
                start = variant * (frames - length) // 2
                clip = pcm[start*2:(start+length)*2]
                fade_in = RATE
                fade_out = RATE * 3
                clip_rms = (sum(x*x for x in clip) / len(clip)) ** 0.5
                clip_gain = min(0.04 / max(clip_rms, 1e-9), 0.30 / max(max(map(abs, clip)), 1e-9))
                values = array.array('h', (round(x * clip_gain * 32767 * min(1, (i//2)/fade_in, ((length-1-i//2)/fade_out)**2)) for i, x in enumerate(clip)))
                write(f"{entry['id']}-{variant}", values)
        else:
            overlap = min(RATE*2, len(pcm)//8)
            overlap -= overlap % 2
            blend = array.array('f', (pcm[len(pcm)-overlap+i]*(1-i/overlap) + pcm[i]*(i/overlap) for i in range(overlap)))
            loop = pcm[overlap:len(pcm)-overlap] + blend
            write(entry['id'], array.array('h', (round(x*32767) for x in loop)))
        print(entry['id'], 'prepared')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, default=ROOT / 'build/atmosphere-originals')
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--only', nargs='+', choices=[entry['id'] for entry in json.loads(MANIFEST.read_text())])
    args = parser.parse_args()
    prepare(args.source_dir, args.download, args.only)
