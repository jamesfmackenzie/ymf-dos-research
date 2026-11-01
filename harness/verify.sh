#!/bin/bash
# usage: verify.sh <experiment-dir>
# Runs every scenario in <experiment-dir>/scenarios.txt and compares the output with the stored results.
# scenarios.txt lines:  <autoexec-file> <expected-result-file> <seconds> [section names to ignore...] [norm:regs,ticks]
# (a 'norm:' token selects compare.py normalisers for values that vary between runs; use '-' as the file for no comparison)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
X="$(cd "$1" && pwd)"; N="$(basename "$X")"; OUT="$ROOT/capture/out/$N"; mkdir -p "$OUT"
fail=0
while read -r auto exp secs ign; do
  case "$auto" in ""|\#*) continue;; esac
  name="$(basename "$auto" .BAT)"; echo "== $N / $name (${secs}s)"
  "$HERE/run-experiment.sh" "$X/$auto" "$secs" > "$OUT/$name.txt" 2>&1
  if [ "$exp" = "-" ]; then echo "  (no stored result; output in capture/out/$N/$name.txt)"; continue; fi
  nrm=""; sec=""
  for t in $ign; do case "$t" in norm:*) nrm="${t#norm:}";; *) sec="$sec $t";; esac; done
  set -- "$OUT/$name.txt" "$X/$exp"
  [ -n "$sec" ] && set -- "$@" --ignore $sec
  [ -n "$nrm" ] && set -- "$@" --norm "$nrm"
  python3 "$HERE/compare.py" "$@" || fail=1
done < "$X/scenarios.txt"
[ $fail = 0 ] && echo "ALL MATCH: $N" || echo "MISMATCHES in $N"
exit $fail
