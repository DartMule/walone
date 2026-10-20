#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    --approved-root-read) sensor_options=(--seconds 120 --stream) ;;
    --approved-root-activation) sensor_options=(--seconds 120 --stream --activate) ;;
    *) printf '%s\n' 'Review docs/sensor.md first.' 'Usage: sensor_experiment.sh --approved-root-read|--approved-root-activation /path/to/Walone.app' >&2; exit 64 ;;
esac
if [ "$(id -u)" = 0 ]; then
    printf '%s\n' 'Run as the ordinary user. Only sensor-probe uses sudo.' >&2
    exit 64
fi
app_path="${2:?Pass the freshly built Walone.app path}"
executable="$app_path/Contents/MacOS/Walone"
if [ ! -x "$executable" ]; then
    printf 'App executable not found: %s\n' "$executable" >&2
    exit 66
fi
if pgrep -x 'Walone' >/dev/null; then
    printf '%s\n' 'Quit Walone before starting the sensor session.' >&2
    exit 64
fi
mkdir -p build/sensor
clang -Wall -Wextra -Werror -O2 tool/sensor-probe.c -framework IOKit -framework CoreFoundation -o build/sensor/sensor-probe
sudo -v
sudo -n build/sensor/sensor-probe "${sensor_options[@]}" | "$executable" --sensor-stdin
