# Experiment 16 - verify how Dsdma traps the 8237 ports

**Question:** do the claims in Finding 15 hold when the real `Dsdma.exe` runs under Jemm?
**Write-up:** [`findings/16-dosbox-x-dynamic-verification.md`](../../findings/16-dosbox-x-dynamic-verification.md)

## What it does
The autoexec runs `DMAT` (channel dump), `VCPI`, `FAKEPCI` (fake Yamaha PCI device 1073:000D), `DMAT`, `DSDMA`, `DMAT`,
`FAKEPCI /D` (dump PCI config and write log), then `TRAPT` (single `IN AL,02` used as the stepping target for the debugger).
Tools are built from `src/trapt.asm` and `harness/src/`.

## Reproduce
```sh
harness/verify.sh experiments/16-trap-verification              # under 1 minute: batch outputs
experiments/16-trap-verification/debugger/verify.sh             # about 4 minutes: stepped trace and memory dumps
```
Both print `ALL MATCH` on success. The debugger run is windowless (it drives DOSBox-X's text debugger through a pty and
needs `pip install pyte`). Prerequisites: [`harness/README.md`](../../harness/README.md) and `samples/ymf744/fetch.sh`.

## Results
| File | Shows | Produced by |
|---|---|---|
| `results/batch-run.txt` | Verbatim run: `T0`/`T1`/`T2` channel dumps before, after loading Dsdma and after; `VCPI`; `F0`; `RC`; `PCI` (cfg 0x42 = 1000, cfg 0x4C = F391) | `harness/verify.sh` |
| `results/trap_seq.txt` | Stepped `IN AL,02`: `#GP` to the IDT stub, the common entry, the handler, back to V86 (`CS:EIP` per step) | `debugger/trap_script.txt` |
| `results/dv_dump.txt` | Memory dumps after Dsdma is resident: TSS/IOPM, IDT stubs, handler code, dispatch table | `debugger/dump_script.txt` |

`debugger/trace_summary.py` reduces the debugger screen output to the stored form. `debugger/bplist.txt` lists the
breakpoints the trace sets.

## Notes
- Earlier notes also held "A" memory snapshots taken before Dsdma had finished installing; the moment of that snapshot
  depended on timing and could not be reproduced, so only the repeatable "B" dumps are kept.
- Dsdma's own banner is the only console output; the evidence is in the channel dumps and traces.

**Status:** verified, batch and debugger parts match.
