#!/bin/sh
# Download the original Yamaha YMF744 DOS driver package and verify it.
# We do not redistribute these binaries; this script fetches them from the original host.
set -e
cd "$(dirname "$0")"
URL="https://www.philscomputerlab.com/uploads/3/7/2/3/37231621/yamaha_ymf744_dos_drivers_with_dsdma.exe_and_ymfirq.exe.zip"
curl -fL -o package.zip "$URL"
mkdir -p extracted && unzip -oq package.zip -d extracted.tmp
# the zip nests everything in one folder; flatten it
d=$(find extracted.tmp -mindepth 1 -maxdepth 1 -type d | head -1)
if [ -n "$d" ]; then mv "$d"/* extracted/; else mv extracted.tmp/* extracted/; fi
rm -rf extracted.tmp
grep -v '^#' SHA256SUMS | (shasum -a 256 -c - 2>/dev/null || sha256sum -c -)
