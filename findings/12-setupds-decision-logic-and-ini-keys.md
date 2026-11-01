# Finding 12 — How `setupds /s` decides to launch DSDMA (decision logic), ds.ini key map

**Date**: 2026-10-08
**Status**: decision logic decoded from the decompiler; individual claims marked
(verified = read directly in disassembly/decompile, inferred = reasoning).

## `setupds` command line (verified, strings in the binary)

`setupds [/s][/?]` — "`/s` : set configuration register", `/?` help. Also refuses to run in
a Windows DOS box. `/s` = **silent apply**: no UI, push the saved `ds.ini` into the card
(and chipset) and exit with an errorlevel. Without `/s` it is the interactive menu
(Configuration / Volume / Select DS-XG / SOUND TEST).

## `ds.ini` is read by setupds only — complete key map (verified, `FUN_0001388c`)

Keys read, in order: `DEBUG`, `REPEAT`, `LEGEN`, `SBIO`, `SBIRQ`, `SBDMA`, `FMIO`, `MPUIO`,
`MPUIRQ`, `JOYIO`, `INTAIRQ`, `IRQMODE`, `DMAMODE`, `FIRSTTRY`, `SLAVEBASE`, **`LOADTSR`**,
**`FORCETSR`**, `IRQSHARE`, `PIRQRC`, `LEGMAS`, `VOICE`, `FM`, mixer words (`MASTER` `MONO`
`PCBEEP` `PHONE` `MIC` `LINE` `VIDEO` `AUX` `PCM`), `SLAVEADDR`, plus file names
(`SBFILE`, `NAFILE`, `FMFILE`). `FORCETSR` is not in the stock ds.ini (reads as 0).
`SLAVEBASE`/`SLAVEADDR` feed a table of three D-DMA base values (base, +0x1000, +0x2000;
base masked `&0xF000`, clamped to 0x1000–0xD000, default 0x8000) used only when
programming a **supported chipset**'s DDMABP (see Finding 11).

## The errorlevel (verified, tail of `FUN_00011dfd`)

Settings struct at `0xA010`: `+0`=LEGEN, `+1`=FORCETSR. Globals: `0xA05E`=LOADTSR.

1. `FUN_000128fb` identifies the **host chipset** by PCI device-ID lookup via B102. IDs it
   knows: `0x7100`, `0x7180`, `0x7190` (Intel 430/440-era host bridges), `0x1543`, `0x0596`,
   `0x0008`, `0x2420` (Intel ICH-era), recorded in a field that stays **0 if nothing matches**.
   Chipset-specific helpers (`FUN_0001263a/126b9/12719/127d5/1289b`) then run for the match.
2. If the field is 0 (**unknown/modern chipset**) and `LOADTSR != 0`, `FORCETSR := 1`.
3. `/s` path (silent): `FUN_00017764` builds and writes the dword at card cfg `0x40`
   (Legacy + Extended Legacy Audio Control), including chipset D-DMA programming where
   supported. Exit code: `1` if its low 2 result bits nonzero (failure); else `2` if
   `LEGEN && FORCETSR`; else `0`.

**Therefore on our machines (X10SAE / Z87 — unknown chipset, stock `LOADTSR=1`, `LEGEN=1`):
`setupds /s` returns 2 → `LOADTSR.BAT` runs `DSDMA`.** On a recognised old chipset it would
program the chipset's native D-DMA instead and return 0 (no TSR). (inferred from the code
shape; the 0-vs-2 outcome for a recognised chipset has not been run on real hardware.)

## Interaction with DSDMA.exe (synthesis so far)

1. `setupds /s` configures the card from `ds.ini` (clock bring-up and reset per Finding 11,
   legacy block at cfg 0x40 dword, per-revision I/O bases at 0x60–0x66 on 0x10/0x12/0x20
   revisions, IRQ at 0x3C) **then** exits 2.
2. `DSDMA.exe` then re-writes `0x40`/`0x42`/`0x4C` from its **hardcoded** defaults
   (220/IRQ5/DMA1/base F390, Finding 5/8) — it never reads ds.ini. These match the *stock*
   ds.ini values (SBIO idx0=220, SBIRQ idx0=5, SBDMA idx1=1), which is why the stock
   combination works. **A user who changes SB port/IRQ/DMA in SETUPDS gets silently
   overridden by DSDMA's constants** (inferred; not hardware-tested).
3. Real SETUPDS-owned behaviours DSDMA lacks: card reset/clock sequencing, IRQ routing
   (cfg 0x3C + chipset PIRQ), the volume/mixer restore, and — via SOUND TEST — real SB DSP,
   IRQ, DMA and FM detection followed by WAV/MIDI playback (strings: "Can not detect DMA at
   channel %d", `SBFILE=YMH8.WAV`, `FMFILE=YMH.MID`, `fmmidi.exe`).

## Warm-up hypothesis update (Finding 9) — CORRECTED, see Finding 13

An earlier draft here said `/s` never touches DMA. **That was wrong.** `setupds /s`
(`FUN_00017764` -> `FUN_00017621`) runs, after writing the config, a real Sound Blaster DSP
reset, an IRQ test (`FUN_0001cb9b`) and a **DMA test** (`FUN_0001cc45`: programs the 8237,
issues a DSP DMA command, polls up to 0x2000 times for the IRQ flag). Details in Finding 13.

## Open

- Decode `FUN_0001b1ab` (the test) to see exactly how it sets up and checks the DMA transfer
  and whether it touches D-DMA registers/ports directly.
- `FUN_0001724f` / `FUN_00017621` (called by the apply path) and `FUN_00013f55` (likely ds.ini
  writer).
- What `0x8000` bit in the cfg-0x40 value means (skips chipset programming when set).
