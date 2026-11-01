#!/bin/bash
# usage: run-experiment.sh <autoexec-file> [seconds]
# e.g.   harness/run-experiment.sh experiments/20-real-extenders/autoexec/AUTOEXEC.A-vcpi-nodsdma.BAT 90
# Rebuilds the image, installs the chosen AUTOEXEC.BAT, boots it and prints the result files.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
case "$1" in /*) A="$1";; *) A="$PWD/$1";; esac
[ -f "$A" ] || { echo "usage: $0 <autoexec-file> [seconds]"; exit 1; }
export MTOOLSRC=/dev/null
"$HERE/build_image.sh" > /dev/null
mcopy -o -i "$ROOT/capture/dosbox/boot.img" "$A" ::AUTOEXEC.BAT
"$HERE/run.sh" ${2:-60}
