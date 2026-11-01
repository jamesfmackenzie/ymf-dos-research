#!/bin/bash
# Re-runs the two debugger scripts and compares with the stored results. Takes about 3 minutes.
# usage: experiments/16-trap-verification/debugger/verify.sh   (from anywhere)
set -u
D="$(cd "$(dirname "$0")" && pwd)"; EXP="$(dirname "$D")"; ROOT="$(cd "$EXP/../.." && pwd)"
export MTOOLSRC=/dev/null ROWS=60
OUT="$ROOT/capture/out"; mkdir -p "$OUT"; fail=0
"$ROOT/harness/run-experiment.sh" "$EXP/autoexec/AUTOEXEC.BAT" 5 > /dev/null 2>&1   # builds the image with TRAPT as the last autoexec step
cd "$ROOT/capture/dosbox" || exit 1
for part in "trap_script seq trap_seq" "dump_script dump dv_dump"; do
  set -- $part
  python3 "$ROOT/harness/dbg.py" "$D/$1.txt" > "$OUT/16-$1.txt" 2>&1; pkill -9 dosbox-x 2>/dev/null
  python3 "$D/trace_summary.py" "$2" "$OUT/16-$1.txt" > "$OUT/16-$3.txt"
  if diff -u "$EXP/results/$3.txt" "$OUT/16-$3.txt" > "$OUT/16-$3.diff"; then echo "  ok     $3"; else echo "  DIFF   $3 (see capture/out/16-$3.diff)"; fail=1; fi
done
[ $fail = 0 ] && echo "ALL MATCH: 16 debugger parts" || echo "MISMATCHES in 16 debugger parts"
exit $fail
