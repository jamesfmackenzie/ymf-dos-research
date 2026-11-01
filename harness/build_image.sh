#!/bin/bash
# Builds capture/dosbox/boot.img: FreeDOS 1.3 floppy + Jemm + Dsdma + every test program.
# Prerequisites and the capture/ layout are described in harness/README.md.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"; W="$ROOT/capture/dosbox"
export MTOOLSRC=/dev/null
S="$ROOT/samples/ymf744/extracted"
[ -f "$S/Dsdma.exe" ] || { echo "Run samples/ymf744/fetch.sh first"; exit 1; }
cd "$W"
# assemble every shared and per-experiment test program into NAME.COM
for a in "$HERE"/src/*.asm "$ROOT"/experiments/*/src/*.asm; do
  n=$(basename "$a" .asm | tr a-z A-Z); nasm -f bin "$a" -o "$n.COM"
done
cp fd13/144m/x86BOOT.img boot.img
M="-i boot.img"
mcopy $M ::freedos/bin/command.com ./command.com.tmp
mdel $M ::setup.bat ::fdauto.bat ::fdconfig.sys
mdeltree $M ::freedos
mcopy $M command.com.tmp ::command.com; rm command.com.tmp
mcopy $M jemm/JEMMEX.EXE jemm/JEMM386.EXE jemm/VCPI.EXE jemm/JLOAD.EXE jemm/QPIEMU.DLL jemm/XMSSTAT.EXE jemm/MEMSTAT.EXE "$S/Dsdma.exe" ::
mcopy $M *.COM ::
# optional third-party / generated extras, copied only when present
for f in HDPMI32.EXE HDPMI16.EXE HDPMI16i.EXE DSDMAL.EXE \
         "$ROOT/capture/ext/binw/dos4gw.exe" "$ROOT/capture/ext/binw/dos32a.exe" \
         "$ROOT/capture/ext/w/XT4G.EXE" "$ROOT/capture/ext/w/XTPW.EXE" "$ROOT/capture/ext/w/XT32.EXE"; do
  [ -f "$f" ] && mcopy $M "$f" ::
done
mcopy $M "$HERE/CONFIG.SYS" ::CONFIG.SYS
mdir $M ::
