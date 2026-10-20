#!/usr/bin/env python3
"""Check every bundled keyboard clip against its original recording.

Checks cover cut attacks/tails, final fades, rumble, PCM format and continuity.
These checks catch known slicing mistakes; they do not replace listening.
Requires ffmpeg. Uses only bundled files, with no network or audible playback.
"""
import array
import argparse
import json
import math
from pathlib import Path
import subprocess
import runpy
import wave

ROOT = Path(__file__).resolve().parents[1] / 'resource_sources'


def decode(path, highpass=False):
    command = ['ffmpeg', '-v', 'error', '-i', str(path)]
    if highpass:
        command += ['-af', 'highpass=f=150']
    return array.array('h', subprocess.check_output(command + ['-f', 's16le', '-ac', '1', '-ar', '48000', '-']))


def rms(values):
    return math.sqrt(sum(value * value for value in values) / max(1, len(values)))


def source_packs(root):
    packs = json.loads((root / 'extra-keyboards.json').read_text())
    model_sources = runpy.run_path(str(Path(__file__).with_name('prepare-model-sounds.py')))['PACKS']
    for pack, sources in model_sources.items():
        names = [f'key{i}' for i in range(len(sources) - 3)] + ['space', 'enter', 'backspace']
        packs.append({'id': pack, 'files': [{'file': name} for name in dict.fromkeys(sources)],
                      'clips': {name: {'file': source, 'start': 0} for name, source in zip(names, sources)}})
    for pack in ['brown', 'red']:
        config = json.loads((root / pack / 'originals/config.json').read_text())
        keys = [(f'key{i}', key) for i, key in enumerate([30, 31, 32, 33, 34, 35])] + [('space', 57), ('enter', 28), ('backspace', 14)]
        clips = {}
        for name, key in keys:
            start, duration = config['defines'][str(key)]
            clips[name] = {'file': 'sound.ogg', 'start': start / 1000, 'end': (start + duration) / 1000}
        packs.append({'id': pack, 'files': [{'file': 'sound.ogg'}], 'clips': clips})
    return packs


def check(root=ROOT, report=None):
    failures = []
    measurements = []
    packs = source_packs(root)
    # Атмосфера имеет отдельный манифест и отдельную проверку.
    actual_paths = {path for path in root.glob('*/*.wav') if path.parent.name != 'atmosphere'}
    expected_paths = {root / pack['id'] / f'{name}.wav' for pack in packs for name in pack['clips']}
    if actual_paths != expected_paths:
        failures.append('Catalog WAV files differ from the source maps')
    for pack in packs:
        originals = {source['file']: decode(root / pack['id'] / 'originals' / source['file']) for source in pack['files']}
        for name, timing in pack['clips'].items():
            pcm = originals[timing['file']]
            start = round(timing['start'] * 48000)
            end = round(timing.get('end', len(pcm) / 48000) * 48000)
            peak = max(rms(pcm[i:min(i + 240, end)]) for i in range(start, end, 48))
            if peak == 0:
                failures.append(f'{pack["id"]}/{name}: silent source')
                continue
            before = rms(pcm[max(0, start - 480):start]) / peak
            attack = rms(pcm[start:start + 240]) / peak
            if before > 0.10 and attack > 0.10:
                failures.append(f'{pack["id"]}/{name}: starts inside an ongoing sound (before={before:.2f}, attack={attack:.2f})')
            edge = rms(pcm[max(start, end - 240):end]) / peak
            continuation = rms(pcm[end:end + 480]) / peak
            if edge > 0.10 and continuation > 0.10:
                failures.append(f'{pack["id"]}/{name}: cut while source is sounding (edge={edge:.2f}, tail={continuation:.2f})')
            path = root / pack['id'] / f'{name}.wav'
            with wave.open(str(path)) as recording:
                if recording.getparams()[:3] != (1, 2, 48000) or not 0 < recording.getnframes() <= 48000:
                    failures.append(f'{pack["id"]}/{name}: invalid PCM format or duration')
                actual = array.array('h', recording.readframes(recording.getnframes()))
            actual_peak = max(rms(actual[i:i + 240]) for i in range(0, len(actual), 48))
            actual_tail = rms(actual[-240:]) / max(1, actual_peak)
            if actual_tail > 0.10:
                failures.append(f'{pack["id"]}/{name}: loud final fade (tail={actual_tail:.2f})')
            if not actual or actual[0] != 0 or actual[-1] != 0 or max(map(abs, actual), default=0) >= 32767:
                failures.append(f'{pack["id"]}/{name}: discontinuous boundary or clipped PCM')
            filtered = decode(path, highpass=True)
            energy = sum(value * value for value in actual)
            high_energy = sum(value * value for value in filtered)
            if energy == 0 or high_energy / energy < 0.10:
                failures.append(f'{pack["id"]}/{name}: fragment dominated by sub-150 Hz rumble')
            measurements.append({'pack': pack['id'], 'clip': name, 'duration_ms': round(len(actual) / 48, 2),
                                 'source_before': round(before, 4), 'source_attack': round(attack, 4),
                                 'source_edge': round(edge, 4), 'source_continuation': round(continuation, 4),
                                 'output_tail': round(actual_tail, 4),
                                 'high_frequency_energy': round(high_energy / max(1, energy), 4)})
    for failure in failures:
        print(f'FAIL {failure}')
    print(f'{len(packs)} packs; {len(measurements)} clips checked; {len(failures)} failures')
    if report:
        report.write_text(json.dumps({'packs': len(packs), 'clips': len(measurements), 'failures': failures,
                                     'measurements': measurements}, indent=2) + '\n')
    return bool(failures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources', type=Path, default=ROOT)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    raise SystemExit(check(args.resources, args.report))
