#!/bin/bash
# Builds the counting Dsdma (DSDMAL.EXE) from your own Dsdma.exe, runs the three extenders under the debugger and
# compares the INT 31h counts with results/counts.txt. About 7 minutes, windowless.
# Needs: samples/ymf744/fetch.sh run, the extender test programs (see experiments/20-real-extenders), pip install pyte.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$D/../.." && pwd)"
export MTOOLSRC=/dev/null ROWS=60
mkdir -p "$ROOT/capture/dosbox" "$ROOT/capture/out"; cd "$ROOT/capture/dosbox" || exit 1
nasm -f bin "$D/tools/lg31.asm" -o lg31.bin || exit 1
python3 "$D/tools/make_dsdmal.py" "$ROOT/samples/ymf744/extracted/Dsdma.exe" || exit 1
"$ROOT/harness/run-experiment.sh" "$D/autoexec/AUTOEXEC.log31.BAT" 5 > /dev/null 2>&1   # builds the image and installs the autoexec
python3 "$ROOT/harness/dbg.py" "$D/debugger/cnt.txt" > "$ROOT/capture/out/21-cnt.txt" 2>&1; pkill -9 dosbox-x 2>/dev/null
python3 "$D/tools/parse_cnt.py" "$ROOT/capture/out/21-cnt.txt" > "$ROOT/capture/out/21-counts.txt"
if diff -u "$D/results/counts.txt" "$ROOT/capture/out/21-counts.txt"; then echo "ALL MATCH: 21-dpmi-host-counters"; else echo "MISMATCHES in 21-dpmi-host-counters"; exit 1; fi
