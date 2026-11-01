# Finding 14 — The interrupt path: setupds selects PCI INTA# (IMOD=1), sets ELCR level mode; DSDMA preserves it

**Date**: 2026-10-08
**Basis**: setupds disassembly (`FUN_00016226`, `FUN_00015f7f`, `FUN_000155f5`, `FUN_0001c713`),
stock `ds.ini`, YMF724F datasheet p.18-19 (SIEN/IMOD, SBIRQ). **(verified)** unless marked.

## Corrections to the earlier picture

- `FUN_00016226` is the **interrupt-protocol** handler (selector at settings+0x25 = `IRQMODE`),
  not a DMA routine. `FUN_000169ab` uses settings+0x26 = `DMAMODE`. I previously mixed these up
  in places.
- `IRQMODE` values: 0 = legacy IRQs (chipset-specific serial-IRQ disable; **unknown chipset
  ORs 0x3f00 = SBIRQ/MPUIRQ := reserved 7** into the 0x40 dword), 1 = **PCI INTA#**
  (`OR 0x80000000` = IMOD=1), 2 = Serialized IRQ (`OR 0x4000` = SIEN, plus PIIX4-style chipset
  reg 0x64 = 0xD0 on known chipsets; unknown chipset again ORs 0x3f00).
- Stock `ds.ini`: **`IRQMODE=1`, `INTAIRQ=5`, `DMAMODE=0`**, `SBIRQ=0` (IRQ5), `SBDMA=1`, `PIRQRC=0`.

## What this means on our machine

1. With stock `IRQMODE=1`, setupds writes IMOD=1 into cfg 0x42 bit 15: the SB-compatible
   block signals its interrupt on **PCI INTA#**, not on a legacy ISA IRQ line. The "IRQ 5" the
   game sees is therefore a *PCI interrupt routed to IRQ5*, not the card driving IRQ5.
2. `FUN_00015f7f` makes that routing work: takes `INTAIRQ` (5), asks the **PCI BIOS** to assign it
   (`INT 1Ah AX=B10Fh`, "Set PCI Hardware Interrupt", wrapper `FUN_0001c713`), writes the value
   to card cfg `0x3C` (Interrupt Line), and then `FUN_000155f5` programs the **ELCR**
   (ports `0x4D0/0x4D1`) to make IRQ5 **level-triggered** (read-modify-write of a saved image at
   `0xA026`). On known chipsets it also programs the chipset's PIRQ route registers.
3. DSDMA never changes IMOD (its `AND 0xE7FF` only clears SMOD) and does not touch the
   SBIRQ/MPUIRQ/SIEN/IMOD bits at all. It only re-reads cfg `0x3C`. So **the entire IRQ
   delivery configuration on a DSDMA system is owned by setupds**; DSDMA depends on it.
4. DSDMA's BLASTER string `I5` is a constant; if the BIOS routing for the bridge's INTA#
   lands on a different IRQ, `0x3C` (re-read by DSDMA into `[717a]`) is the only place that
   would reveal it.

## Why this matters for the bridge setups

- The IDT 89HPEB383 / ASM1083 swizzle INTA# of the downstream slot onto a different upstream
  pin; the legacy IRQ the game gets depends on BIOS PIRQ routing + `setupds`'s B10F/ELCR
  programming, not on anything DSDMA does. A wrong or unprogrammed route would show as "SB IRQ
  test failed" -> `setupds /s` errorlevel 1 -> DSDMA not loaded. Since we do reach DSDMA on real
  hardware, routing to IRQ5 does work there. (inferred; consistent with Finding 7.)
- Level-triggered IRQ5 matters: a leftover edge-triggered ELCR bit with INTA# (active-low,
  level) is a classic cause of lost or stuck interrupts. Testable: read ports 0x4D0/0x4D1
  before/after `setupds /s`.

## Tests added to the hardware checklist

- Dump cfg 0x40-0x43 after `setupds /s` and after `DSDMA`: expect IMOD (0x42 bit 15)=1,
  SBIRQ(0x41 bits 2:0)=0, SMOD=3 then 2.
- Dump ELCR (0x4D0,0x4D1) and cfg 0x3C before/after `setupds /s`.
- Set `IRQMODE=0` in ds.ini and see the unknown-chipset 0x3f00 path (SBIRQ=7 reserved) — expect
  a failed IRQ test (predicted; destructive to nothing but worth confirming).
