# Finding 9 — what `SETUPDS` actually does, and a new warm-up hypothesis

**Date**: 2026-10-08
**Status**: reasoning from already-established facts (Finding 8, the earlier notes'
real-hardware results) plus one new, testable hypothesis — not yet disassembly-confirmed
for `SETUPDS.exe` itself (DOS4GW/LE protected-mode binary, a bigger undertaking than
`Dsdma.exe`'s plain MZ format — not attempted yet).

## `SETUPDS`'s two jobs, and which one actually matters at runtime

1. **Writes `ds.ini`.** Per Finding 8, this file is read by nothing except `SETUPDS`
   itself (`setupds /s`, the silent re-check at the top of `LOADTSR.BAT`). `DSDMA.exe`
   never reads it. Close to vestigial as far as `DSDMA.exe`'s behavior goes.
2. **Directly programs the card's live PCI config registers** — the same `0x40`/`0x42`
   region (Legacy Audio Control / Extended Legacy Audio Control) `DSDMA.exe` itself later
   writes (Finding 5). Confirmed by inference from the earlier notes' established result: FM
   synthesis works immediately after running `SETUPDS`, *before* `DSDMA.exe` ever loads —
   and FM needs no DMA, just register writes, so something must already be live-configuring
   the card at that point. `SETUPDS` is the only candidate.

## Why this doesn't explain the D-DMA base discrepancy (already settled)

Whatever D-DMA base `SETUPDS` configures (`8000` this session) gets overwritten by
`DSDMA.exe`'s hardcoded `0xF390` the moment `LOADTSR.BAT` reaches the bare `DSDMA`
invocation (Finding 8). Variation in `SETUPDS`'s own chosen base can't explain anything
about `DSDMA.exe`'s later runtime behavior — it's deterministic regardless.

## The more promising angle: SETUPDS as an inadvertent warm-up step

The D-DMA base address is a *relocatable decode window* into one physical engine on the
chip — not a separate engine per base value. If `SETUPDS`'s own verification pass (or its
`SOUND TEST` menu option) drives a real transfer through that engine while it's decoded at
base `8000`, and `DSDMA.exe` later just relocates the *same* engine's window to `0xF390`
without issuing Master Clear (confirmed absent, Finding 1/4), there's no reason to expect
the engine's internal state (Mode register, mask bits, Command register) gets reset by the
relocation alone — only Master Clear is documented to reset those. That means a
`SETUPDS`-driven transfer could plausibly leave the engine "primed" in a way that survives
the later base change, functioning as the same kind of warm-up Duke Nukem 3D provided in
the original investigation — just one step earlier in the boot sequence, and via a
different program.

**This is a real, testable hypothesis for the Finding 7 "why did the Doom baseline stop
reproducing" puzzle** — not confirmed, but concrete and cheap to check.

## Next real-hardware test to add

Deliberately vary whether `SETUPDS`'s `SOUND TEST` menu option gets used during setup,
across otherwise-identical cold-boot attempts, and see if that correlates with whether
Doom's demo-end hang reproduces. If it does, that's a second, independent "something else
primes the DMA engine before a real transfer is attempted" data point alongside the
original Duke-Nukem-3D finding — and would mean `SETUPDS` itself needs to be avoided (or
deliberately exploited) for clean before/after testing of the Master Clear fix.

## Related

- Finding 7 (`07-real-hardware-test-session-inconclusive.md`) — the puzzle this extends.
- Finding 8 (`08-dsdma-never-reads-ds-ini.md`) — establishes why `ds.ini` itself isn't the
  answer, motivating this follow-up toward `SETUPDS`'s live PCI writes instead.
