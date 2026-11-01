# Finding 11 — `setupds.exe` loaded via custom LE extractor; first trace of its PCI behaviour

**Date**: 2026-10-08
**Status**: first pass. Loader works; PCI layer and several key routines mapped from Ghidra
decompiler output. Not yet traced: the exact chipset-capability decision that sets
`setupds /s`'s errorlevel, and what `SOUND TEST` does.

## Loader (done)

- `tools/le/leparse.py` — ~40-line LE parser (header at `e_lfanew` = `0x30A8`; object table,
  page map, data pages at absolute file offset `0x8400`). Writes `obj1..3.bin` + manifest.
  Sanity check: 37 pages * 0x1000 (last page 0xCC0) + `0x8400` == file size exactly.
- Objects: obj1 code `0x10000` (0x1CF9F), obj2 `0x30000` (0x1E), obj3 data/stack
  `0x40000` (0xB760). Entry = obj1+`0xF8B0`. Fixups are **not applied** (objects sit at their
  preferred bases, so absolute refs are right as-is; relocated/segment refs would not be).
- Import: `analyzeHeadless ... -import capture/setupds_le/obj1.bin -loader BinaryLoader
  -loader-baseAddr 0x10000 -processor x86:LE:32:default -postScript AddLeObjects.java`
  (adds obj2/obj3 as blocks). Project: `ghidra_projects/SetupdsProject`.
- Scripts: `FindSetupdsIO.java` (INT/IN/OUT census → script output, not shipped),
  `DecompSetupds.java <addr...>` (decompiles to `capture/decomp/*.c`, gitignored).

## How it reaches PCI

No literal `INT 1Ah` or CF8/CFC: Watcom `int386` patches the vector at runtime. PCI BIOS is
reached via a wrapper library at `0x1C242`–`0x1C5xx`, one function per B1xx call:

| Addr | Call | Role |
|---|---|---|
| 1c242 | B101 | PCI present / last bus |
| 1c29a | B102 | find device |
| 1c34a / 1c3b9 / 1c429 | B108/9/A | read cfg byte/word/dword |
| 1c498 / 1c504 / 1c571 | B10B/C/D | write cfg byte/word/dword |

## What SETUPDS does to the card (new, matches the YMF724F datasheet)

Main init is `FUN_00011dfd`. It finds the card; **if BAR0 (0x10) is unassigned it sizes and
assigns one itself** (`FUN_00012e8c`: all-ones write/readback, classic BAR probe); then sets
up legacy audio (`FUN_00015f7f`), and calls:

- `FUN_00010010`: read cfg `0x48` (DS-1 Control); if low bits set, write `v|3` then `v&0xFC`
  — **pulses CRST (AC-link reset) and XRST (local-device reset)**.
- `FUN_00013099`: staged writes to cfg `0x4A` (DS-1 Power Control) with delays
  (`FUN_0001f0fc`) between them — clears DMC, then DPLL0/1, then PSL/PSN power-save bits;
  also writes `0x4E = 0` for certain revisions and sets `0x48 |= 4`.

So SETUPDS performs a **chip-level reset and clock/PLL bring-up** of the YMF724/744. The
legacy block (OPL3 + SB Pro engine, PSL0) is exactly what these bits gate. `DSDMA.exe`
does none of this (Finding 5: it only writes `0x40/0x42/0x4C`).

## SETUPDS also programs the *chipset's* D-DMA registers

`FUN_000164b1` / `FUN_000166f7` write cfg `0x90` (2 bits per channel; `01`/`10`) and `0x92`
(base pointer) on a chipset device — matching PIIX4 `PDMACFG`/`DDMABP` (Intel §4.1.17–18,
`docs/piix4-ddma-reference.md`). Other helpers poke `0x45/0x47/0x59/0x68/0x70-73/0x7C/0x80-0x8A`
on (presumably) other chipset families — **mapping to specific chipsets not yet verified**.
That is the real "chipset supports D-DMA → use hardware path, else exit 2 → DSDMA" logic.

## Implications for the warm-up hypothesis (Finding 9)

Strengthened but still untested on hardware: SETUPDS resets the AC-link/local device and
re-sequences card clocks on *every* run, so Doom's behaviour can legitimately depend on
whether (and when) SETUPDS ran. A reset in SETUPDS is not itself evidence it touches the
D-DMA slave engine (no D-DMA slave Master Clear anywhere in the sampled functions), so the
Master-Clear theory remains unconfirmed; the cold-boot-after-SETUPDS vs. skip-SETUPDS test
is now better motivated.

## Still to do

- Decode `FUN_00012bb9`/`FUN_00014278`/`FUN_0001442d` (device-ID/revision gating, cfg `0x04`
  command-register writes) and find the `/s` errorlevel exit path.
- Trace `SOUND TEST` (menu strings in obj3) to see if it starts a DMA transfer.
- Verify revision values (`DAT_00009ffa` = 0x10/0x12/0x20) against the datasheet.
