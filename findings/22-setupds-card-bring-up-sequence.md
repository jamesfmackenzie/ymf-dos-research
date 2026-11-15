# Finding 22 — What `setupds /s` does to a YMF724F, step by step

**Date**: 2026-10-26 (analysis); written up as a finding 2026-11-14
**Basis**: the `setupds.exe` decompile and disassembly (main routine `FUN_00011dfd` and the functions named below; addresses are
the linear addresses of the loaded LE image, base 10000h), the stock `ds.ini`, the YMF724F datasheet, the register names in Linux
`sound/pci/ymfpci/ymfpci.h`, and a register dump taken on a real YMF724F (X10SAE, 2026-10-27, cold boot; from the maintainer's
unpublished notes, so not reproducible from this repo). Each row is tagged **(verified)** where it was read in the decompile or
seen in the dump, and **(inferred)** where it rests on reasoning.

This is the card bring-up that `setupds /s` performs, in order, for anyone replacing it. It complements Finding 12 (decision
logic and `ds.ini` keys), 13 (end to end) and 14 (interrupt path). Findings 11 and 13 mention parts of it in passing; this
finding is the full sequence, and where they differ this one is the later and more detailed reading. The function addresses are
given so each fact can be traced.

## The sequence

The order below is the call order in `FUN_00011dfd`. "Stock" means the stock `ds.ini` (Finding 12).

| # | Step | What it does to the card | Tag |
|---|---|---|---|
| 1 | Parse `ds.ini`, find the card (`FUN_0001388c`, PCI BIOS B102h) | Stock values: LEGEN=1, SBIO=0 (220h), SBIRQ=0 (IRQ 5), SBDMA=1, MPUIO=0 (330h), MPUIRQ=0, JOYIO=0, INTAIRQ=5, IRQMODE=1, DMAMODE=0. Mixer values are masked as they are loaded: LEGMAS, VOICE and FM with 77h; MASTER, PCM, LINE, CD, VIDEO and AUX with 9F1Fh; MONO, PCBEEP and PHONE with 801Fh; MIC with 805Fh. | verified |
| 2 | Assign BAR0 if it is zero (`FUN_00012e8c`) | cfg 04h is saved and its low three bits cleared (I/O, memory, bus master off), the BAR is sized with an all-ones write and a base is written to cfg 10h, then cfg 04h is restored. BAR0 is the card's 32 KB of audio registers. | verified |
| 3 | IRQ routing (`FUN_00015f7f`) | PCI BIOS B10Fh routes INTA# to INTAIRQ (5); cfg 3Ch = 05h; the edge/level register (4D0h/4D1h) is read-modify-written to make IRQ 5 level-triggered. See Finding 14. | verified |
| 4 | IRQ scan (`FUN_0001591b`) | Probes free IRQs. Purpose not traced; probably bookkeeping for the menu. | inferred |
| 5 | **Power-up** (`FUN_00013099`) | Reads cfg 4Ah. **Only if it is not 0:** clear bit 0 (DMC), wait; clear bits 2:0 (DPLL1/DPLL0), wait; clear bits 5:0 (PSN/PSL1/PSL0). If the 744/754 gate (below) is true, cfg 4Eh = 0. Then, if bit 13 (PR5) is **clear**: clear bit 12 (PR4, the AC-link) together with bits 5:0, wait, then clear bits 15:8 (all PRx). If PR5 is **set** and the gate is true: set cfg 48h bit 2, wait, then clear bits 15:8. If PR5 is set and the gate is false: clear bits 15:8, then repeat the AC-link reset and codec wait of step 8. Bits 7:6 are always kept. The datasheet default for 4Ah is 0000h, so on a cold boot this step does nothing. | verified |
| 6 | DMA-mode decision (`FUN_00013386`) | Pure logic. On an unknown chipset it picks the reserved SMOD = 3 path (Finding 13). | verified |
| 7 | **Native block quiesce** (`FUN_00014278`) | cfg 04h \|= 06h (memory space and bus master; the old value is saved). Through BAR0: +84h = 0 (NATIVEDACOUTVOL); +108h = 0001_0000h then 0 (MODE: pulse the bit-16 reset of the native engine); +150h, +154h, +158h, +15Ch, +160h = 0 (MAPOFREC, MAPOFEFFECT, PLAYCTRLBASE, RECCTRLBASE, EFFCTRLBASE); +80h = 3FFF_3FFFh (LEGACYOUTVOL, both channels at maximum). Register names are from Linux; the values are from the decompile. | verified |
| 8 | **AC-link reset and codec ready** (`FUN_000102b5` calls `FUN_00010010`, then `FUN_000100e7`) | Reads cfg 48h. **Only if bits 1:0 are not 0**, writes the value with bits 1:0 set, then the value with bits 1:0 cleared (CRST#/XRST# released). Then polls BAR0+66h bit 15 (primary codec busy) until clear, at most 700,000 reads; then reads AC'97 register 26h up to 20,000 times with a one-port-read delay between reads, until (value & 0Fh) = 0Fh. Returns failure on either timeout. The datasheet default for 48h is 0001h, so a cold boot takes the release path. | verified |
| 9 | Secondary codec probe (`FUN_00010183`) | Only if the 744/754 gate is true. Not for the 724F. | verified |
| 10 | DOS buffer (`FUN_000108b3`) | One DPMI allocation, for the self-test DMA. | verified |
| 11 | **Microcode download** (`FUN_000132d1` calls `FUN_00013278`) | Copies dword images into BAR0 instruction RAM: two copies (DSP and controller) for every part except one device value (12h), which gets one. Sizes match Linux's DSPLENGTH and CTRLLENGTH. The destination offsets (1000h and 4000h) are from the earlier trace, not re-checked here. | verified (copies), inferred (offsets) |
| 12 | Start the native DSP | BAR0+114h = 1 (CONFIG). | verified |
| 13 | Branch on the command line | One flag skips straight to step 17. Of the other two cases, one runs step 14 and the other runs the mixer writes and the menu (`FUN_0001b1ab`, `FUN_00013f55`) instead. The step 14 case is taken to be `/s` (it ends in the exit codes of step 19), but which settings flag is `/s` was not confirmed. The menu case was not traced. | verified (three-way branch), inferred (which is `/s`), not traced (menu) |
| 14 | **Write the legacy dword** (`FUN_00017764` calls `FUN_000144a8`, `FUN_00016226`, `FUN_000169ab`, then writes cfg 40h) | See the next section. | verified |
| 15 | **Mixers** (`FUN_0001724f`, called from `FUN_00017764` after the cfg 40h write) | **Sound Blaster mixer**, only when the Sound Blaster base selector is below 4, through SBbase+4/+5: index 22h, then 04h, then 26h; each data byte is (value × 2) \| 11h, so the stock value 77h is written as FFh (each nibble 2n+1). The three bytes are taken to be LEGMAS, VOICE and FM (they are consecutive and masked with 77h by the loader); the byte-to-key mapping was not confirmed. **AC'97 mixer** through `FUN_00010326`: registers 02h, 06h, 0Ah, 0Ch, 0Eh, 10h, 12h, 14h, 16h, 18h (master, mono, PC beep, phone, mic, line, CD, video, aux, PCM) with the masked values of step 1; repeated for a secondary codec if one was found. A codec write is: word at BAR0+62h = register \| (codec number << 8), word at +60h = data, then poll +66h (secondary: +6Ah) bit 15 for at most 1,000 reads. A read is: +62h = 8000h \| register \| (codec << 8), poll the same bit, then read the word at +64h (secondary +68h) 600 times and keep the last. | verified |
| 16 | Self-test (`FUN_00017621`) | DSP reset (bit 0), IRQ (bit 1), 8237 DMA (bit 2; on an unknown chipset it can only fail), FM (bit 3). Bits 1:0 decide exit code 1. | verified (bit meanings from Finding 13) |
| 17 | Status report (`FUN_000170a9`) | Reads cfg 40h and prints what is enabled; helpers `FUN_00016cca`, `FUN_00016e56`, `FUN_00016edc`, `FUN_0001701f` do the per-block probing for the message. Not traced further. | verified (report), not traced (probing) |
| 18 | **Tear-down** (`FUN_0001442d`) | BAR0+114h = 0 (native DSP stopped); BAR0 unmapped; cfg 04h restored to the value saved in step 7. | verified |
| 19 | Exit code | 1 if self-test bits 1:0 are not 0; otherwise 2 if LEGEN and FORCETSR are both set; otherwise 0 (Finding 12). | verified |

**The 744/754 gate.** Steps 5, 8 and 9 test one stored word against 10h, 12h and 20h. It is the upper half of the dword that
the card search stores, which is most likely the PCI device ID (the 744 and 754 are device IDs 10h and 12h in Linux; 20h is not
an ID I can place). A YMF724F is device 0Dh, revision 03h, so it fails the test whether the word is the device ID or the
revision, and none of the gated branches run on it. **(inferred, which field; verified, that the 724F skips the branches)**

## The cfg 40h dword

Built by `FUN_00017764` from the stock `ds.ini`.

- **Low word (cfg 40h) = 3F4Fh (verified on hardware, explained below).** The four enables SBEN, FMEN, MPU and joystick
  give 000Fh; SBDMA = 1 gives 0040h; 3F00h fills the SBIRQ and MPUIRQ fields with 7 (reserved). MIEN (bit 4) is not set
  anywhere in the builder, so it stays 0.
- **High word (cfg 42h) = 9800h.** SMOD = 11b (the reserved unknown-chipset path) and IMOD = 1 (`IRQMODE=1`, PCI INTA#).

**Where 3F00h comes from.** The builder `FUN_000144a8` has its own `OR 3F00h`, separate from the two in Finding 14: when a
mode byte in the settings equals 1 it fills both IRQ fields with 7; otherwise it writes the SBIRQ and MPUIRQ values from
`ds.ini`. With the stock file the result is 004Fh \| 3F00h = 3F4Fh, which is exactly what the hardware dump shows. Finding
14 listed the 3F00h only for IRQMODE 0 and 2, so that finding was incomplete: the stock IRQMODE of 1 takes the builder's own
branch. **Which `ds.ini` key is that byte is not pinned down.** IRQMODE is the obvious candidate (value 1 means INTA#, where
the ISA IRQ fields are unused), but the field offsets in the decompile do not obviously line up with Finding 14's, so treat
the link to IRQMODE as **(inferred)**.

Dsdma then sets SMOD to 10b (`AND E7FFh`, `OR 1000h`, giving 9000h), rewrites SBEN and SDMA in 40h, and writes 4Ch = F391h.
It never touches IMOD, MIEN or the IRQ fields (Findings 5 and 14).

## Checked on hardware (2026-10-27, YMF724F rev 03, cold boot, from the maintainer's notes)

- **Before setupds:** cfg 04h = 0006h (the BIOS already sets memory space and bus master); 40h = 0000_907Fh; 48h = 0001h;
  4Ah = 0000h; 4Ch = 0000h; BAR0+80h already 3FFF_3FFFh; +84h, +108h and +114h = 0; edge/level register 4D0h = 20h (IRQ 5 level).
- **After `setupds /s`:** cfg 40h = 9800_3F4Fh; 48h = 0000h; 4Ah and 4Ch unchanged; edge/level register still 20h; BAR0+108h and
  +114h = 0; last codec command 18h = 0808h; 26h = 000Fh.
- The values agree with the sequence above: the step 5 branch is skipped (4Ah starts at 0), the step 8 release path is taken
  (48h goes 0001h to 0000h), the quiesce and tear-down leave +108h and +114h at 0, and the low word is 3F4Fh.

## Corrections to earlier findings

- **Finding 13, step 3** said "pulse CRST+XRST" unconditionally. The pulse happens only if cfg 48h bits 1:0 are not 0 (Finding 11
  had this right). It also lists the power-up before the chipset identification; the call order is BAR0, interrupt routing,
  power-up, DMA-mode decision, quiesce, AC-link reset.
- **Finding 11** said `FUN_00013099` "sets `0x48 |= 4`". That happens on one branch only (PR5 set, 744/754 gate true).
- **Finding 14** gave the 3F00h only for IRQMODE 0 and 2; see above.

## What is not covered

The interactive path (no `/s`), the probing helpers behind step 17, the secondary codec on 744/754 parts, and which `ds.ini` key
drives the 3F00h branch. None of them changes what `setupds /s` does to a 724F on the stock configuration.
