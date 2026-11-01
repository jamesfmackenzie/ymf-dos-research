#!/bin/sh
# Regenerate the full ndisasm listings that earlier findings cite (not shipped: they are
# complete disassemblies of a copyrighted binary). Needs `samples/ymf744/fetch.sh` run first and
# `ndisasm` (from nasm). The listings were checked byte for byte against NASM 3.02;
# other versions should produce the same instructions but may format lines differently.
set -e
cd "$(dirname "$0")/.."
D=samples/ymf744/extracted/Dsdma.exe
[ -f "$D" ] || { echo "Dsdma.exe not found. Run samples/ymf744/fetch.sh first to download the Yamaha package." >&2; exit 1; }
command -v ndisasm >/dev/null || { echo "ndisasm not found. Install nasm (e.g. 'brew install nasm' or 'apt install nasm')." >&2; exit 1; }
echo "Using $(ndisasm -v 2>&1 | head -1)"
mkdir -p capture/listings
ndisasm -b 16 -e 0x200 "$D" > capture/listings/dsdma-ndisasm-fileoffset-basis.txt  # code starts at file offset 0x200
ndisasm -b 16 -e 0x790 "$D" > capture/listings/dsdma-ndisasm-ip-basis.txt          # IP basis: IP 0 = file 0x790
echo "Wrote capture/listings/dsdma-ndisasm-fileoffset-basis.txt and dsdma-ndisasm-ip-basis.txt"
