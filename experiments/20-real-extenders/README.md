# Experiment 20 - real DOS extenders with and without Dsdma

**Question:** at what privilege level do DOS/4GW, PMODE/W and DOS/32A run, and are their port accesses trapped?
**Write-up:** [`findings/20-real-extender-vs-dsdma-dpmi-host.md`](../../findings/20-real-extender-vs-dsdma-dpmi-host.md)

## Programs (`src/`)
- `xt.c`: one source built for three extenders. Reads CS (CPL) and IOPL, programs channel 1's address via the flip-flop, reads it back and the status port.
- `qc.asm`: `QC.COM`, the QPI callback counter.

## Prerequisites
```sh
harness/build_extenders.sh      # downloads Open Watcom (about 150 MB, once) and builds XT4G/XTPW/XT32.EXE in capture/ext/
```
It compiles `src/xt.c` with Open Watcom's DOS tools inside DOSBox-X for each extender (DOS/4GW, PMODE/W, DOS/32A) and
leaves the extender runtimes in `capture/ext/binw/`. The Open Watcom "Current-build" snapshot is a moving release; any
recent one with `wcl386` should work (the executables we built from the snapshot of 2026-10-11 are reproduced
byte for byte).

## Run
```sh
harness/verify.sh experiments/20-real-extenders     # about 3.5 minutes; prints ALL MATCH on success
harness/run-experiment.sh experiments/20-real-extenders/autoexec/AUTOEXEC.A-vcpi-nodsdma.BAT 90   # or one scenario by hand
```
| Autoexec | Result | Scenario |
|---|---|---|
| `AUTOEXEC.A-vcpi-nodsdma.BAT` | `results/runA.txt` | QPIEMU loaded, no Dsdma: the extenders run via Jemm's VCPI |
| `AUTOEXEC.B-qpi-then-dsdma.BAT` | `results/runB.txt` | QPIEMU loaded, then Dsdma: extenders run under Dsdma's DPMI host |
| `AUTOEXEC.C-dsdma-then-qpi.BAT` | `results/runC.txt` | Dsdma loaded, then QPIEMU: the V86 DMA probe (`DMAT`) stops responding and the run ends at the time limit; cause not investigated |
| `AUTOEXEC.D-dsdma-then-qpi-nov86.BAT` | `results/runD.txt` | As C, skipping the V86 probe: the extenders run, QPI callback counts are 0 |

**Status:** verified, all four scenarios match section by section, including the run C hang.
