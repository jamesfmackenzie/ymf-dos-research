# Experiment 19 - do I/O traps reach protected-mode clients?

**Question:** are QPI callbacks and Dsdma's traps seen by a VCPI protected-mode client and by a DPMI client?
**Write-up:** [`findings/19-pm-client-io-trapping.md`](../../findings/19-pm-client-io-trapping.md)

## Programs (`src/`)
- `pmt.asm`: VCPI protected-mode client (`PMT V`; `PMT Q` adds a QPI callback on port 02)
- `dpmit.asm`: 16-bit DPMI client via INT 2Fh 1687h (`DPMIT`; `DPMIT Q` adds the QPI callback)

## Run
Needs `HDPMI16.EXE`, `HDPMI16i.EXE` in `capture/dosbox/` (see `harness/README.md`).
```sh
harness/verify.sh experiments/19-pm-client-trapping     # about 1.5 minutes; prints ALL MATCH on success
harness/run-experiment.sh experiments/19-pm-client-trapping/autoexec/AUTOEXEC.run2-dsdma.BAT 60   # or one scenario by hand
```

## Scenarios and results
| Autoexec | Result file | Scenario |
|---|---|---|
| `AUTOEXEC.run1-jemm-vcpi-client.BAT` | `results/run1-jemm-vcpi-client.txt` | VCPI PM client (`PMT V`), then QPIEMU loaded and `PMT Q` |
| `AUTOEXEC.run2-dsdma.BAT` | `results/run2-dsdma.txt` | Baseline `DPMIT`, then Dsdma loaded: `PMT V`, `DPMIT`, `DPMIT Q` (no QPIEMU loaded) |
| `AUTOEXEC.run3-hdpmi.BAT` | `results/run3-hdpmi.txt` | QPIEMU + HDPMI16, then HDPMI16i; carries a stale QPI callback from an earlier program, so use run 4 |
| `AUTOEXEC.run4-hdpmi16i-clean.BAT` | `results/run4-hdpmi16i-clean.txt` | QPIEMU + HDPMI16i, `DPMIT Q`: the clean result |

**Status:** verified, all four scenarios match section by section.
