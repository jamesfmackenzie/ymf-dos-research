# Finding 8 — `DSDMA.exe` never reads `ds.ini`; the hardcoded defaults always win

**Date**: 2026-10-08
**Resolves**: the Finding 7 loose end (live D-DMA base `0xF390` vs. `SETUPDS`'s displayed
`D-DMA BASE: 8000`).

## The decisive check

Searched the raw `Dsdma.exe` binary for every plausible string a `ds.ini` reader would
need to contain: `ds.ini`, `DS.INI`, and the two relevant INI keys confirmed present in the
stock `ds.ini` (`SLAVEBASE`, `SLAVEADDR` — the ASCII config keys for exactly the D-DMA base
this project has been tracking as `[0x7174]`). **None of these strings appear anywhere in
the binary.** `DSDMA.exe` has no file-parsing logic for `ds.ini` at all — full stop, not a
maybe.

Checked the actual stock `loadtsr.bat` (not just the patched version already documented in
the earlier notes) to see how `DSDMA.exe` gets invoked:
```
@echo off
setupds /s
if errorlevel 2 goto loadtsr
set blaster=A220 I5 D1 T4
goto break

:loadtsr
DSDMA

:break
```
**`DSDMA` is invoked completely bare — no command-line arguments at all.**

## What this means

`SETUPDS.exe` is the only thing that ever reads or writes `ds.ini`. Whatever base address
it displays or writes there (`8000` in the real-hardware session) is irrelevant to
`DSDMA.exe`'s actual behavior, because `DSDMA.exe` has no mechanism to learn about it —
neither via the file `SETUPDS` wrote, nor via a command-line argument `LOADTSR.BAT` doesn't
pass. **`DSDMA.exe` always uses its own hardcoded defaults**
(`SB port=0x220`, `IRQ=5`, `DMA channel=1`, `D-DMA base=0xF390` — from the `1059:014c`
block, Finding 4) in the stock installed configuration, every single time it loads.

This cleanly and fully explains Finding 7's puzzle — no further investigation needed on
that specific question.

## A refinement, not a contradiction, to Finding 5's command-line-parsing read

`FUN_1059_a64f` (Finding 5) does read the PSP command-line tail early on (`INT 21h,
AH=62h` + `ES:[0x80]`), storing a pointer to it — but it then **unconditionally** calls the
hardcoded-defaults function (`1059:014c`) immediately afterward, before any check of that
command-line content is visible in what's been traced so far. The likely shape: `DSDMA.exe`
probably *does* support command-line overrides for power users invoking it manually with
explicit arguments (consistent with there being command-line-parsing code at all — it
wouldn't exist for no reason), but the hardcoded defaults are set first regardless, and
since the stock `LOADTSR.BAT` never passes arguments, any override path (if one exists
further in the function, not yet traced) simply never triggers in the standard installed
configuration. Worth a quick confirming trace if this ever becomes load-bearing, but not
necessary to settle the Finding 7 question — that's already fully resolved above.

## Bigger-picture implication for the "generalized software DMA master" project

A from-scratch reimplementation doesn't need to parse `ds.ini` at all to match
`DSDMA.exe`'s actual real-world behavior — the stock Yamaha installation never does either.
Worth keeping in mind when writing the reimplementation spec in Phase 4: matching the real,
observed behavior means hardcoding sensible defaults (or taking command-line args, mirroring
`DSDMA.exe`'s own apparent-but-unused support for that), not building `ds.ini`-parsing logic
that the original tool never actually exercises in normal use.
