#!/bin/bash
# usage: run.sh [seconds]  -- boot capture/dosbox/boot.img in DOSBox-X for up to N seconds (earlier if the autoexec writes DONE.TXT), then print the *.TXT result files from the image
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(dirname "$HERE")/capture/dosbox"
cd "$W" || exit 1; export MTOOLSRC=/dev/null
# watchdog in case DOSBox-X never exits (a modal quit dialog or a hard guest hang)
dosbox-x -conf "$HERE/dosbox-x.conf" -fastlaunch -nomenu -time-limit ${1:-25} > run.log 2>&1 &
DPID=$!; ( sleep $(( ${1:-25} + 30 )); kill -9 $DPID 2>/dev/null ) & WPID=$!; disown $WPID
# stop early once the autoexec has written DONE.TXT (the marker that ends every scenario that finishes);
# scenarios that hang never write it and run to the time limit
( while kill -0 $DPID 2>/dev/null; do
    sleep 2
    if mdir -b -i boot.img ::DONE.TXT >/dev/null 2>&1; then sleep 3; kill $DPID 2>/dev/null; break; fi
  done ) &
SPID=$!; disown $SPID
wait $DPID 2>/dev/null; kill $WPID $SPID 2>/dev/null
for f in $(mdir -b -i boot.img :: | grep -i '\.TXT'); do echo "== $f"; mtype -i boot.img $f; done
