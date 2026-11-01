# Finding 13 — End-to-end: what `LOADTSR.BAT`, `setupds /s` and `DSDMA.exe` do together

**Date**: 2026-10-08
**Basis**: Findings 1-12. Everything marked **(verified)** was read directly from the
disassembly/decompile of `Dsdma.exe` or `setupds.exe`, or the YMF724F datasheet; **(inferred)**
is reasoning not yet exercised on hardware.

## Boot-time sequence on an unknown-chipset machine (X10SAE / Z87-PRO with bridge)

`LOADTSR.BAT`: `setupds /s` -> `if errorlevel 2 goto loadtsr` -> `DSDMA` (stock sets BLASTER only
in the *non*-DSDMA branch; our patched copy sets it in both).

### Stage A — `setupds /s` (verified unless noted)

1. Parse `ds.ini` (key map in Finding 12). Find the card (PCI B102), compute `DAT_9ffa`
   revision gating (0x10/0x12/0x20 = newer parts get extra I/O-base regs at cfg 0x60-0x66).
2. If BAR0 unassigned, size and assign it (all-ones probe).
3. Reset and clock bring-up: pulse CRST+XRST (cfg 0x48), then staged writes to DS-1 Power
   Control (cfg 0x4A) with delays; for 0x10/0x12/0x20 revisions also `0x4E = 0`.
4. Identify the **host chipset** (known IDs: 0x7100/7180/7190 Intel 430/440, 0x1543, 0x596 VIA,
   0x8, 0x2420 Intel ICH). **Ours is not in the list -> chipset id = 0.**
5. Build and write the dword at card cfg `0x40` (Legacy Audio Control + Extended):
   - legacy bits from ds.ini (`FUN_000144a8`: LEGEN, FM/SB/MPU/JOY enables and I/O choices),
   - **SMOD (bits 28:27) = `FUN_000169ab`**: for `DMAMODE=0` (PC/PCI, the stock value) on a
     recognised chipset it programs the chipset's PCI-DMA enable and yields 0; for
     `DMAMODE=1` (D-DMA) on a recognised chipset it programs chipset PDMACFG/DDMABP *and writes
     card cfg 0x4C = base + 1 itself*; **on an unrecognised chipset it yields `3`** (datasheet:
     reserved; SETUPDS UI calls it "NOT ASSIGN"). It never writes cfg 0x4C in that case.
6. Restore legacy SB mixer volumes via the SB mixer ports (base+4/+5; regs 0x22,0x04,0x26 from
   `LEGMAS`/`VOICE`/`FM`) — this needs the legacy block already live at the chosen SB port.
7. **Self-test** (`FUN_00017621`): SB DSP reset (bit0 = not found), IRQ test via DSP (bit1 =
   fail), then a **real DMA test** (`FUN_0001cc45`): allocate DOS buffer inside a 64K page,
   program the 8237 and issue a DSP DMA command, spin up to 0x2000 reads for the IRQ flag
   (bit2 = fail), FM probe (bit3). On chipsets 0x7100/7180/7190/0x596, a failed DMA test makes
   `FUN_000174fe` toggle a chipset register (0xB1 / 0x7D) bit 0..2 and re-test up to 3 times;
   **for unknown chipsets it does nothing**.
8. Exit code: `1` if bits 0|1 set (SB DSP or IRQ not working), else `2` if `LEGEN && FORCETSR`
   (FORCETSR auto-set because chipset id = 0 and `LOADTSR=1`), else `0`.
   DMA-test failure (bit 2) alone does **not** change the errorlevel.

### Stage B — `DSDMA.exe` (Findings 1,5,8; correction to 5 above)

1. Hardcoded defaults (SB 0x220, IRQ 5, DMA 1, D-DMA base 0xF390); `ds.ini` never read.
2. PCI probe, then writes: cfg `0x40` (SBEN + SDMA field), cfg `0x42` (SBIO select **and
   SMOD := 2 = Distributed DMA**), cfg `0x4C` (base | CE=1 — the D-DMA slave enable), reads
   cfg `0x3C` for IRQ. Enters PM via VCPI, then sets IOPM bits in the host TSS and patches the host IDT #GP gate in place; the #GP handler emulates trapped 8237 accesses in software (Finding 15).
3. **Never issues Master Clear (+0Dh) or Request (+09h)** to the slave block, and does not
   reset the card.

## What this explains / what it changes

- **Why errorlevel 2:** unknown chipset + stock `LOADTSR=1` => `FORCETSR`. (verified)
- **Why SETUPDS's displayed D-DMA base differs from the live one:** SETUPDS only uses it for
  *recognised* chipsets; DSDMA ignores ds.ini and uses 0xF390. (verified)
- **Config handover is lossy (inferred):** SETUPDS-chosen SB port/IRQ/DMA are overwritten by
  DSDMA's constants (cfg 0x40/0x42). Stock ini values coincide with the constants, so default
  setups are unaffected; non-default selections would silently revert.
- **The card is in SMOD=3 (reserved) with CE=0 while SETUPDS's DMA test runs** (inferred
  from the code; the datasheet defines no behaviour for SMOD=3). So the DMA test on our
  machine can only fail, and it leaves a DSP DMA command issued with no completion. That
  half-finished DSP/DMA transaction, followed by DSDMA enabling D-DMA, is a **concrete new
  candidate for the "warm-up" effect** that does not require any Master Clear: the first
  *real* transfer after load may start from state left by the aborted test.
  (The Duke Nukem 3D "warm-up" would then be playing the same role.) Untested.

## Testable predictions (for the next real-hardware session)

1. Run `setupds /s` alone, then `DSDMA`, then Doom: expect the original hang pattern if the
   aborted DMA test matters. Compare with: skip `setupds /s` entirely (run DSDMA from a cold
   boot after only the SDE fix) — if SETUPDS's reset/clock/test sequence is what Doom
   depends on, behaviour differs.
2. Reverse: does the hang disappear if the DSP is reset (e.g., via a tiny DEBUG script writing
   1 then 0 to SBbase+6 after DSDMA) before launching Doom? That would implicate the stale
   DSP state rather than D-DMA slave state. (A DEBUG script for this can be drafted next.)
3. `SOUND TEST` in the interactive menu is a *successful* version of the same transfer only
   if D-DMA is already live — i.e. only if run **after** DSDMA is loaded (possible since
   SETUPDS can be launched with DSDMA resident). That ordering is itself a clean
   "warm-up" experiment.

## Still open

- Meaning of the ">=0x8000 bit" short-circuit in `FUN_00017764` and `FUN_00016226`'s role.
- Whether SMOD=3 vs 0 changes the SB DSP's DMA request behaviour (datasheet silent).
- `fmmidi.exe` / WAV playback paths (SOUND TEST internals) — lower priority.
