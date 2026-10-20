#!/usr/bin/env python3
"""Повторить profile-замеры с чередованием рендереров (запускать через очередь)."""

import argparse
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import sys


def summarize(output, device):
    summary = {}
    for renderer in ['skia', 'impeller']:
        runs = [json.loads(path.read_text()) for path in sorted(output.glob(f'{device}-{renderer}-*.json'))]
        scenarios = {}
        for scenario in ['keyboard_scroll', 'statistics_scroll', 'timer_animation']:
            frames = [frame for run in runs for frame in run[scenario]['frames']]
            if not frames:
                continue
            metrics = {'frames': len(frames), 'runs': len(runs)}
            for field in ['build_us', 'raster_us', 'total_us']:
                values = sorted(frame[field] / 1000 for frame in frames)
                metrics[field.removesuffix('_us') + '_ms'] = {
                    'p50': statistics.median(values),
                    'p95': values[min(len(values) - 1, int(len(values) * .95))],
                    'p99': values[min(len(values) - 1, int(len(values) * .99))],
                    'max': max(values),
                }
            metrics['stage_over_budget_pct'] = 100 * sum(
                max(f['build_us'], f['raster_us']) > 1000000 / 120 for f in frames
            ) / len(frames)
            metrics['per_run_stage_over_budget_pct'] = [
                100 * sum(max(f['build_us'], f['raster_us']) > 1000000 / 120
                          for f in run[scenario]['frames']) / len(run[scenario]['frames'])
                for run in runs
            ]
            scenarios[scenario] = metrics
        summary[renderer] = scenarios
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', default='macos', choices=['macos', 'windows'])
    parser.add_argument('--runs', type=int, default=3)
    parser.add_argument('--summarize-only', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    flutter = root / '.fvm/flutter_sdk/bin' / ('flutter.bat' if sys.platform == 'win32' else 'flutter')
    output = root / 'build/renderer-benchmark'
    output.mkdir(parents=True, exist_ok=True)
    if args.summarize_only:
        summarize(output, args.device)
        return
    for run in range(1, args.runs + 1):
        order = ['skia', 'impeller'] if run % 2 else ['impeller', 'skia']
        for renderer in order:
            name = f'{args.device}-{renderer}-{run}'
            print(f'Starting {name}', flush=True)
            command = [str(flutter), 'drive', '--profile', '--no-pub', '-d', args.device,
                       '--enable-impeller' if renderer == 'impeller' else '--no-enable-impeller',
                       '--driver=test_driver/integration_test.dart',
                       '--target=integration_test/renderer_performance_test.dart']
            with (output / f'{name}.log').open('w') as log:
                subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)
            source = root / 'build/integration_response_data.json'
            data = json.loads(source.read_text())
            if 'timer_animation' not in data:
                raise RuntimeError(f'Incomplete results: {name}')
            shutil.copyfile(source, output / f'{name}.json')
            print(f'Completed {name}', flush=True)
    summarize(output, args.device)


if __name__ == '__main__':
    main()
