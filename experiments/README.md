# Experiments and evidence index

Every finding rests on one of four kinds of evidence. Only the dynamic ones have a folder here.

| Findings | Evidence | Where |
|---|---|---|
| 1-5, 8-15 | Static analysis of `Dsdma.exe` / `setupds.exe` (ndisasm, Ghidra) | Not shipped as dumps. See `docs/reproducing.md` and `findings/excerpts/` |
| 6-7 | Real-hardware Master Clear protocol and session | `tools/debug_scripts/MCLEAR.TXT`; write-ups in the findings |
| 16 | DOSBox-X trap verification | [`16-trap-verification`](16-trap-verification/) |
| 17 | QPIEMU vs Jemm DMA-port overlap | [`17-qpiemu-port-overlap`](17-qpiemu-port-overlap/) |
| 18 | Source review of SBEMU/VSBHDA | No experiment (reading only) |
| 19 | Do traps reach protected-mode clients? | [`19-pm-client-trapping`](19-pm-client-trapping/) |
| 20 | Real DOS extenders with and without Dsdma | [`20-real-extenders`](20-real-extenders/) |
| 21 | INT 31h usage counters | [`21-dpmi-host-counters`](21-dpmi-host-counters/) |

Each experiment folder has the same layout: `README.md` (question, how to run, which result backs which
claim), `src/` (test programs), `autoexec/` (the boot script per scenario), `results/` (captured
output) and sometimes `debugger/` or `tools/`. The shared tooling is in [`../harness/`](../harness/).

## Reproducing
Every experiment can be re-run and checked: `harness/verify.sh experiments/<NN>-<name>` runs its `scenarios.txt` and
reports `ALL MATCH` or the differing sections. Experiments 16 and 21 also have a debugger-driven part with its own
`verify.sh` (see their READMEs). Typical durations: 16 under 1 min (plus about 4 min for the debugger parts), 17 about 4 min, 19 about 1.5 min,
20 about 3.5 min, 21 about 6 min.
