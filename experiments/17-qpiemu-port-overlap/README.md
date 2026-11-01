# Experiment 17 - QPIEMU vs Jemm's own DMA port traps

**Question:** can a QPI client take over the DMA ports (00-0F, 81-8B, C4-DE) that Jemm already traps?
**Write-up:** [`findings/17-qpiemu-vs-jemm-dma-port-overlap.md`](../../findings/17-qpiemu-vs-jemm-dma-port-overlap.md)

## What it does
`src/qt.asm` is a real-mode test, modelled on Jemm's `JLM/QPIEMU/Test/TESTDMA.ASM`. With Jemm and its QPIEMU loaded
(CONFIG.SYS `DEVICE=\JEMMEX.EXE V`, then `JLOAD QPIEMU.DLL`) it traps ports through QPI and records what reaches the
callback. `QT <part>`:

| Part | Test | Autoexec | Stored result |
|---|---|---|---|
| `0`-`9`, `:` | IN/OUT/string battery on one port group each | `AUTOEXEC.battery.BAT` | `qt-battery-per-port.txt` (sections Q00-Q10) |
| `A` | channel 2 pre-emption, pass-through readback, untrap, QPI 1A00/1A01 vs IN | `AUTOEXEC.partA.BAT` | `qt-A-special-tests.txt` |
| `B` | timing: 1000 OUTs on trapped vs untrapped ports | `AUTOEXEC.partB.BAT` | `qt-B-timing.txt` |
| `R` | `REP OUTSD` on a trapped port (02): **hangs by design** | `AUTOEXEC.partR.BAT` | `qt-R-rep-outsd-hang.txt` |
| `S` | control: `REP OUTSD` with no trap: **hangs by design** | `AUTOEXEC.partS.BAT` | `qt-S-control.txt` |

The hanging parts show the output stopping after the setup lines; the run is ended by the harness time limit. `S` shows
the hang is not caused by the trap (Jemm alone hangs on `REP OUTSD`).

## Reproduce
```
harness/verify.sh experiments/17-qpiemu-port-overlap      # about 4 minutes; prints ALL MATCH on success
```
Needs the prerequisites in [`harness/README.md`](../../harness/README.md) (DOSBox-X, FreeDOS image, Jemm).
Comparison is section by section. Two kinds of value legitimately differ between runs and are normalised
(see `scenarios.txt`): `regs` (scratch-buffer `si/di` addresses, which move with the `QT.COM` build, and
uninitialised upper register halves) and `ticks` (BIOS-tick timings in part B depend on host speed).

**Status:** verified, all five scenarios match.
