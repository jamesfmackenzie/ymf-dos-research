# Experiment 21 - which INT 31h functions do real extenders use?

**Question:** how large a DPMI subset does a replacement host need? Measured by counting calls into Dsdma's INT 31h dispatcher.
**Write-up:** [`findings/21-dsdma-dpmi-host-anatomy.md`](../../findings/21-dsdma-dpmi-host-anatomy.md)

## How it works
`tools/lg31.asm` is a small counter routine. `tools/make_dsdmal.py` patches a copy of your own `Dsdma.exe` into
`DSDMAL.EXE`: a code cave at file offset 0x9790 and a jump at 0x3DB0 (INT 31h entry 0x361D, after the VM test). The counter byte
for AX=AHAL sits at image IP `0x9100 + (AH&0x1F)*16 + (AL&0xF)` (resident at linear F7C09100 under Jemm), saturating at 255.
The patch is made on the user's machine; no patched binary is shipped.

## Reproduce
```sh
experiments/21-dpmi-host-counters/verify.sh        # about 6 minutes, windowless; prints ALL MATCH on success
```
It builds `lg31.bin` and `DSDMAL.EXE` from your own `Dsdma.exe` (run `samples/ymf744/fetch.sh` first), boots the image
with `autoexec/AUTOEXEC.log31.BAT`, and runs `debugger/cnt.txt` through `harness/dbg.py`. At each stop (after Dsdma loads, then
after each of DOS/4GW, PMODE/W and DOS/32A) it runs `dv f7c09100+k*0x70` for k = 0..4 (DOSBox-X `dv` shows only 112 bytes per
command). `tools/parse_cnt.py` turns that raw output into the counts, which are compared with `results/counts.txt`.
Needs the extender test programs (`harness/build_extenders.sh`) and `pip install pyte`.

## Results
`results/counts.txt`: INT 31h function counts per extender (DOS/4GW, PMODE/W, DOS/32A).

**Status:** verified (two identical runs). The first DOS/4GW row differs by +1 on functions 0006, 000B and 000C from the numbers
first recorded; the later reproduced values are the ones stored, and the set of functions used is unchanged.
