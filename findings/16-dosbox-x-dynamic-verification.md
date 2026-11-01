# Finding 16 — DOSBox-X dynamic verification of Finding 15

**Date**: 2026-10-10
**Basis**: DOSBox-X 2026.10.01 (core=normal, Pentium) booting FreeDOS 1.3 with
`DEVICE=\JEMMEX.EXE` (Jemm 5.86), DOSBox-X XMS/EMS/UMB off, real unmodified
`samples/ymf744/extracted/Dsdma.exe`. Harness: `harness/`; sources and logs: `experiments/16-trap-verification/`.
Tags: **verified** = observed in this run; **inferred** = reasoning only; **not tested**.

## Setup (verified)
- Jemm VCPI works: `VCPI.EXE` reports version 1.0, PM entry 00110698, PIC bases 8/70.
- Dsdma.exe needs a PCI BIOS, which DOSBox-X lacks. A 100-line TSR stub (`FAKEPCI.COM`,
  INT 1Ah B101/B102/B108-B10D, fake device 1073:000D) satisfies the probe without editing
  the sample. Dsdma then installs, exit code 0, and writes cfg 0x42=1000 (SMOD=10b,
  SBIO=220) and cfg 0x4C=F391 (base F390 + CE) — matching Findings 5/13 exactly (`PCI.txt`).
- The D-DMA slave at F390 is not emulated by DOSBox-X: hooked-channel accesses read FF.

## Finding 15 claims
| Claim | Result |
|---|---|
| Handler 0x1020 is "installed as the host IDT vector 13 gate" | **Refined.** IDT[13] = `0048:68B4` and IDT[14] = `0048:68B8` (verified via debugger `idt`). These are Dsdma's per-vector stubs (`call 0x6C80`, `E8 CD 03 90`), 0x6880+4*vec. 0x6C80 saves state, switches to Dsdma's stack, then dispatches through a table at `[0x78C0]` (count 0x18, 4-byte records); the record `0D 03 20 10` maps vector 13 -> 0x1020. The code at F7C01020 is resident and byte-identical to the disassembly. So 0x1020 is the vector-13 handler, but via the stub + table, not a direct gate. |
| Only #GP patched | **Wrong/incomplete.** #PF (vector 14) is also hooked, to `0048:68B8`. Purpose resolved by Finding 21: demand commit of DPMI extended memory (handler 0x5FBE), unrelated to DMA trapping. Other vectors keep Jemm's gates. |
| Gate patched in place; original saved | **Verified (location refined).** Original Jemm gates for vectors 13/14 (`D4 08 11 00 08 00`, `D8 08 11 00 08 00`) sit at F7C07A52 (vector 13 at 0x7A02+13*6 = 0x7A50, off by 2: the 0x7A02 base in F15 is approximate; **inferred** it is 0x7A04). |
| IOPM bits set for 00-0F, C0-DE, 81-8B, PIC | **Refined.** Diff of TSS IOPM (base word 0x88, TSS F8017000) before/after load: Jemm already traps 00-07,0A-0F, 81/82/83/87/89/8A/8B, 64, 92 (A20 gate), C4-C7, D4,D6,D8-DE. Dsdma *adds only*: 08,09 (byte1 FC->FF), 20,21 and A0,A1 (PICs), C0,C2, D0,D2. F15 implied Dsdma sets page-register bits; it does not need to (Jemm VDMA did). |
| #GP -> handler -> resume to V86 | **Verified (partly).** Stepping a V86 `IN AL,02` shows CS:EIP go to `0048:68B4` -> `0048:6C80` (CPL0, Dsdma stack F8004Fxx), then back in V86 at the next instruction with AL=FF (`trap_seq.txt`). Not captured: the decode steps inside 0x1020 itself. |
| Non-hooked channels passed through | **Verified.** After load, ch0/2/3 address/count, page regs 81/82/87/89/8A/8B, ch5 (C4) and temp/0F readbacks are identical to the pre-load baseline. Only ch1 (ports 02/03, page 83) is hooked (reads FF; status 08 changes 00->22). Pass-through is still a #GP: `IN AL,04` also enters `0048:68B4` and returns the real 34. |
| REP INSB/OUTSB | **Verified.** `REP OUTSB` + `REP INSB` on port 2 is trapped and decoded without crash, data lands on the (unbacked) slave (reads FFFF); on unhooked port 4 the same string I/O round-trips (3412) before load; after load only ch1 differs. |
| Before/after Jemm's VDMA | **Partly.** Dsdma's stub is IDT[13], ahead of Jemm's gate, so Dsdma sees every #GP first (verified). Pass-through data matches Jemm VDMA baseline, but I could not tell whether Dsdma chains to the saved Jemm gate or re-issues the IN/OUT itself (**not tested**). |
| A20 behaviour | **Not tested.** Port 92 is in Jemm's IOPM before and after, unchanged by Dsdma (verified), consistent with "no A20 handling". `IN AL,92` was in `TRAPT.COM` but not stepped. |

## Debugger/emulator caveats
- DOSBox-X has no I/O-port breakpoints and does not log unbacked I/O; evidence comes from
  stepping with `BPINT`, register snapshots (`trap_seq.txt`) and `DV` memory dumps
  (`dv_dump.txt`, TSS/stub/handler/table).
- The `bppm` memory watchpoints set in the trace script fire spuriously on page-table
  aliasing (extra stops at `0048:693C`, `CS=0290`); they are not Dsdma behaviour.
- `MEMDUMPBIN` wraps at 64K above 1 MB; use `DV`.

## Next
Count of IOPM bytes beyond port 0xDF and the record layout of the `[0x78C0]` table remain
partly interpreted; a breakpoint inside 0x1020 with `-time-limit` runs would show the
chain-or-reissue question.
