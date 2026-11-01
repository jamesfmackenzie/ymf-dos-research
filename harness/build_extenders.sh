#!/bin/bash
# Builds the three extender test programs used by Experiments 20 and 21 (XT4G.EXE, XTPW.EXE, XT32.EXE) from
# experiments/20-real-extenders/src/xt.c, using the Open Watcom v2 DOS tools run inside DOSBox-X. Also leaves
# the extender runtimes (dos4gw.exe, pmodew.exe, dos32a.exe) in capture/ext/binw/, where build_image.sh looks.
#
# usage: harness/build_extenders.sh            (downloads about 150 MB once; takes a few minutes)
# env:   EXT_DIR=<dir>   work directory (default: capture/ext)
# Open Watcom's "Current-build" snapshot is a moving release, so the exact file changes over time; any recent
# snapshot with wcl386 and the DOS4G/PMODE/W/DOS32A system libraries should work.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
EXT="${EXT_DIR:-$ROOT/capture/ext}"; mkdir -p "$EXT/w"
SNAP="$EXT/ow-snapshot.tar.xz"
URL=https://github.com/open-watcom/open-watcom-v2/releases/download/Current-build/ow-snapshot.tar.xz

[ -f "$SNAP" ] || { echo "Downloading Open Watcom snapshot (about 150 MB)..."; curl -fL -o "$SNAP" "$URL"; }
if [ ! -f "$EXT/binw/wcl386.exe" ]; then
  echo "Extracting compiler, headers and libraries..."
  tar -xJf "$SNAP" -C "$EXT" ./binw ./h ./lib386
fi

cp "$ROOT/experiments/20-real-extenders/src/xt.c" "$EXT/w/XT.C"
cat > "$EXT/w/BUILD.BAT" <<'B'
@ECHO OFF
SET WATCOM=C:\
SET PATH=C:\BINW;%PATH%
SET INCLUDE=C:\H
SET LIB=C:\LIB386;C:\LIB386\DOS
CD \W
wcl386 -q -bt=dos -l=dos4g XT.C -fe=XT4G.EXE > B1.TXT
wcl386 -q -bt=dos -l=pmodew XT.C -fe=XTPW.EXE > B2.TXT
wcl386 -q -bt=dos -l=dos32a XT.C -fe=XT32.EXE > B3.TXT
ECHO DONE > BDONE.TXT
EXIT
B
sed -i '' 's/$/\r/' "$EXT/w/BUILD.BAT" 2>/dev/null || true
rm -f "$EXT/w/BDONE.TXT" "$EXT/w"/XT4G.EXE "$EXT/w"/XTPW.EXE "$EXT/w"/XT32.EXE

echo "Building in DOSBox-X..."
cd "$EXT"
dosbox-x -conf "$HERE/ext-build.conf" -fastlaunch -nomenu -time-limit 400 > build.log 2>&1 &
DPID=$!; ( sleep 430; kill -9 $DPID 2>/dev/null ) & WPID=$!; disown $WPID
until [ -f w/BDONE.TXT ] || ! kill -0 $DPID 2>/dev/null; do sleep 3; done
kill $DPID 2>/dev/null || true; kill $WPID 2>/dev/null || true; wait $DPID 2>/dev/null || true

for f in XT4G XTPW XT32; do
  [ -f "w/$f.EXE" ] || { echo "FAILED: w/$f.EXE was not built (see $EXT/w/B*.TXT and build.log)"; exit 1; }
done
echo "Built: $(ls "$EXT"/w/XT*.EXE | tr '\n' ' ')"
