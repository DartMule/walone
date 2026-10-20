#!/usr/bin/env python3
"""Measure fresh Release processes against an isolated copy of local metadata."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import sqlite3
import statistics
import subprocess
import tempfile
import time
import uuid


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def measure(pid):
    output = run("footprint", "-p", str(pid), "--noCategories", "--format", "bytes")
    values = {}
    for key in ("phys_footprint", "phys_footprint_peak"):
        match = re.search(rf"\b{key}:\s+(\d+) B", output)
        if not match:
            raise RuntimeError(f"Missing {key}: {output}")
        values[key] = int(match[1])
    return values


def probe(process, output):
    stages = []
    previous = 0
    deadline = time.monotonic() + 240
    while not (output / 'done').exists():
        if process.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Memory probe exited or timed out')
        marker = output / 'stage.json'
        if not marker.exists():
            time.sleep(.1)
            continue
        stage = json.loads(marker.read_text())
        if stage['id'] == previous:
            time.sleep(.1)
            continue
        previous = stage['id']
        readings = []
        for _ in range(3):
            readings.append(measure(process.pid))
            time.sleep(1)
        name = stage['name']
        if name == os.environ.get('WALONE_TRACE_STAGE'):
            with (output / 'metal-trace.log').open('w') as log:
                subprocess.run(['xcrun', 'xctrace', 'record', '--template', 'Metal System Trace',
                                '--attach', str(process.pid), '--time-limit', '5s',
                                '--output', str(output / 'metal.trace')],
                               stdout=log, stderr=log, timeout=45)
        (output / f'{name}-vmmap.txt').write_text(run('vmmap', '-summary', str(process.pid)))
        stable = statistics.median(row['phys_footprint'] for row in readings)
        stages.append({**stage, 'stable_bytes': stable, 'readings': readings})
        print(f'{name}: {stable / 2**20:.1f} MiB', flush=True)
        (output / f'{previous}.continue').write_text('ok')
    (output / 'stages.json').write_text(json.dumps(stages, indent=2) + '\n')
    return stages


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--seconds", type=int, default=20)
    parser.add_argument("--max-mib", type=float)
    parser.add_argument("--max-playing-mib", type=float,
                        help="Budget for the median music_animated stage, not the final pause")
    parser.add_argument("--renderer", choices=("impeller", "skia"))
    parser.add_argument("--no-glass", action="store_true")
    parser.add_argument("--wide-gamut", action="store_true")
    parser.add_argument("--probe", choices=("empty", "visual", "animation", "slider", "progress-only", "visualization-only", "workspace", "media", "music", "music-render", "music-active"),
                        help="Use a Release build of tool/memory_probe.dart")
    args = parser.parse_args()
    if args.max_playing_mib is not None and args.probe not in ("music-active", "music-render"):
        parser.error("--max-playing-mib requires --probe music-active or music-render")
    if args.runs < 1 or args.seconds < 5:
        parser.error("Use at least one run and five seconds per run")
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.app / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    support = Path.home() / "Library/Application Support"
    source_data = support / info["CFBundleIdentifier"] / "WaloneFlutter"
    bundle_id = f"dev.soyjanks.walone.memory{uuid.uuid4().hex}"
    fixture = support / bundle_id
    samples = []
    try:
        with tempfile.TemporaryDirectory(prefix="walone-memory-") as temporary:
            app = Path(temporary) / "Walone.app"
            run("ditto", str(args.app), str(app))
            info["CFBundleIdentifier"] = bundle_id
            info["WaloneEnableWideGamut"] = args.wide_gamut
            if args.renderer:
                info["FLTEnableImpeller"] = args.renderer == "impeller"
            with (app / "Contents/Info.plist").open("wb") as destination:
                plistlib.dump(info, destination)
            # Benchmark copies have their own identity and never replace the installed app.
            run("codesign", "--force", "--deep", "--sign", "-", str(app))
            for index in range(args.runs):
                data = fixture / "WaloneFlutter"
                data.mkdir(parents=True)
                for source in source_data.glob("*.json"):
                    shutil.copy2(source, data / source.name)
                if args.probe:
                    (data / 'appearance.json').write_text(json.dumps({
                        'followSystem': False, 'transparency': .75,
                        'compactPlayer': True, 'themeMode': 'light',
                    }))
                if args.no_glass:
                    appearance = data / "appearance.json"
                    settings = json.loads(appearance.read_text()) if appearance.exists() else {}
                    settings.update(followSystem=False, transparency=0)
                    appearance.write_text(json.dumps(settings))
                library = source_data / "Music/library.json"
                if library.exists():
                    (data / "Music").mkdir()
                    shutil.copy2(library, data / "Music/library.json")
                database = source_data / "statistics.sqlite"
                if database.exists():
                    with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as src:
                        with sqlite3.connect(data / database.name) as dst:
                            src.backup(dst)
                with (args.output / f"run-{index + 1}.log").open("w") as log:
                    environment = dict(os.environ)
                    if args.probe:
                        probe_output = (args.output / f'probe-{index + 1}').resolve()
                        probe_output.mkdir(parents=True)
                        environment.update(WALONE_MEMORY_PROBE=str(probe_output),
                                           WALONE_MEMORY_SCENARIO=args.probe)
                    process = subprocess.Popen(
                        [str(app / "Contents/MacOS" / info["CFBundleExecutable"])],
                        stdout=log, stderr=log, env=environment,
                    )
                    try:
                        if args.probe:
                            stages = probe(process, probe_output)
                            samples.append({'stable_bytes': stages[-1]['stable_bytes'],
                                            'peak_bytes': max(r['phys_footprint_peak']
                                                for s in stages for r in s['readings']),
                                            'stages': stages})
                            continue
                        started = time.monotonic()
                        readings = []
                        for second in range(1, args.seconds + 1):
                            time.sleep(max(0, started + second - time.monotonic()))
                            if process.poll() is not None:
                                raise RuntimeError(f"App exited; see run-{index + 1}.log")
                            readings.append({"second": second, **measure(process.pid)})
                        summary = run("vmmap", "-summary", str(process.pid))
                        (args.output / f"run-{index + 1}-vmmap.txt").write_text(summary)
                        stable = statistics.median(
                            row["phys_footprint"] for row in readings[-5:]
                        )
                        peak = max(row["phys_footprint_peak"] for row in readings)
                        samples.append({"stable_bytes": stable, "peak_bytes": peak,
                                        "readings": readings})
                        print(f"Run {index + 1}: stable {stable / 2**20:.1f} MiB, "
                              f"peak {peak / 2**20:.1f} MiB", flush=True)
                    finally:
                        # Only this test-owned process writes to this disposable fixture.
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait()
                        if args.probe and fixture.exists():
                            shutil.rmtree(fixture)
                shutil.rmtree(fixture)
    finally:
        if fixture.exists():
            shutil.rmtree(fixture)
        subprocess.run(["defaults", "delete", bundle_id],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    result = {"app": str(args.app), "renderer": args.renderer, "no_glass": args.no_glass, "wide_gamut": args.wide_gamut,
              "probe": args.probe,
              "seconds": args.seconds, "runs": samples,
              "median_stable_mib": statistics.median(
                  row["stable_bytes"] for row in samples) / 2**20,
              "median_peak_mib": statistics.median(
                  row["peak_bytes"] for row in samples) / 2**20}
    playing = [stage['stable_bytes'] / 2**20 for sample in samples
               for stage in sample.get('stages', []) if stage['name'] == 'music_animated']
    if playing:
        result['median_playing_mib'] = statistics.median(playing)
    (args.output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Median: {result['median_stable_mib']:.1f} MiB stable, "
          f"{result['median_peak_mib']:.1f} MiB peak", flush=True)
    if args.max_mib is not None and result["median_stable_mib"] > args.max_mib:
        raise SystemExit(f"Over memory budget: {args.max_mib} MiB")
    if args.max_playing_mib is not None and result['median_playing_mib'] > args.max_playing_mib:
        raise SystemExit(f"Over playing memory budget: {result['median_playing_mib']:.1f} > {args.max_playing_mib} MiB")


if __name__ == "__main__":
    main()
