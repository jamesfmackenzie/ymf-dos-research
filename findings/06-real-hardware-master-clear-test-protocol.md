# Finding 6 — Phase 3 revised: a real-hardware Master Clear test protocol

**Date**: 2026-10-07
**Status**: drafted, **not yet run** — requires the physical X10SAE/YMF724 setup from the
earlier notes. This document is the ready-to-execute test for next time that
hardware session happens.

## Why DOSBox-X was ruled out for Phase 3

Checked DOSBox-X's actual PCI bus implementation (`pci_bus.cpp`, via its published Doxygen
source) before investing in building a bootable test environment. **It registers exactly
two PCI device classes: an S3 VGA card and a 3dfx Voodoo card — no sound devices, no
D-DMA-capable peripheral of any kind.** `DSDMA.exe`'s own PCI BIOS presence check
(`INT 1Ah AX=B101h`) would likely succeed (DOSBox-X does have a real PCI BIOS), but the
Device-ID matching step traced in Finding 5 would find nothing resembling a YMF724 and hit
`DSDMA.exe`'s own error-return path immediately — never reaching the VCPI trap
installation or the D-DMA accessor functions at all. Building a full DOSBox-X environment
would be real effort spent on a test that structurally cannot exercise the code path this
project actually cares about. Dynamic verification has to happen on the real card.

## The actual decisive test

Finding 5 pins down exactly where Master Clear would live if it existed:
**`(D-DMA base address) + 0xD`**, where the base address is whatever got written to the
card's own PCI config offset `0x4C` (upper 12 bits, per the YMF724F datasheet's
"D-DMA Slave Configuration" register) during `DSDMA.exe`'s init. Finding 4/5 also clarified
there's no PIIX4-style multi-channel-group addressing happening on the card side — this
card exposes one 16-byte register block at one base address, and the accessor functions
hit it directly (offsets `0`–`0xF`) with no additional channel-based offset math. That
means the test doesn't need to guess or hardcode a base address at all — it can read the
*same* register `DSDMA.exe` itself already wrote, directly off the live PCI bus, via the
same `DEBUG.COM`/PCI-BIOS technique used throughout the earlier notes'
bring-up session.

**One thing worth calling out rather than silently assuming away**: a real 8237's Master
Clear also masks all four DMA channels as a side effect (standard 8237 behavior — Command
register reset, Temporary register cleared, Request register cleared, all channel mask
bits set). This is not a problem for this test: whatever game runs after the poke (Doom)
will, as part of its own completely normal SB16 programming sequence, reprogram Mode and
unmask its channel before its very first sound effect — same as it does on every real
SB16-compatible system, every time. The poke doesn't need a manual "unmask" follow-up.

## Protocol

**Setup** (unchanged from the earlier notes' already-proven YMF724/X10SAE session):
bridge legacy bit pre-confirmed by Supermicro, root-port `SDE` applied (Device 28/Function
5), `SETUPDS` run, FM audio confirmed working as a baseline sanity check.

**Step 1 — baseline reproduction (control).** Boot cold. Run `LOADTSR.BAT` (`DSDMA.exe`
loads normally, no reboot — the already-fixed 512MB XMS cap via `HIMEMX`/`JEMM386`
prerequisite from the earlier bring-up session still applies). Launch Doom, confirm sound
works, let a demo play to its end (or press Esc early, per the earlier notes' established
repro technique) — **expect the known hang**. This confirms nothing about the session has
drifted before testing the fix.

**Step 2 — reset and apply the fix.** Reboot (clean slate — the hang from Step 1 may leave
the system in a bad state). Boot cold, run `LOADTSR.BAT` again. Before launching Doom, run
the script below via `DEBUG < MCLEAR.TXT`.

**`MCLEAR.TXT`** (new script, follows the exact same `A`/assemble/`G`/`Q` pattern as the
project's existing `BRIDGEFX.TXT`/`ROOTPORT.TXT`/`IDTLEGACY.TXT` scripts):

```
A 100
MOV AX,B102
MOV CX,000D
MOV DX,1073
XOR SI,SI
INT 1A
MOV AX,B109
MOV DI,004C
INT 1A
MOV DX,CX
AND DX,FFF0
ADD DX,000D
MOV AL,00
OUT DX,AL
INT 3

G=100
Q
```

What it does, in order: (1) PCI `Find Device` for Vendor `1073h`/Device `000Dh` (Yamaha
YMF724F — same ID the earlier notes' IRQ-workaround investigation already confirmed is
correct for this card), carrying `BH:BL` (bus/device-function) forward automatically, the
same way every other script in this project's toolkit does; (2) PCI `Read Config Word` at
offset `0x4C` — the exact register `DSDMA.exe` itself wrote during its own init (Finding
5); (3) mask off the low 4 bits (`CE`/`TS`/`EA`) to get the pure base address; (4) add
`0xD` — the Master Clear offset; (5) `OUT` a byte to that computed port. The data value
written is irrelevant (Master Clear is a pure strobe on a real 8237, and this card's D-DMA
slave block is documented to mimic that register shape) — `0x00` is used by convention.

**Step 3 — retest.** Launch Doom immediately after the poke. Let a demo play to its end
(or Esc early). **If the hang doesn't occur**, this is a direct, causal confirmation of the
Master Clear theory — not just "the code to do it is absent" (already proven statically)
but "manually doing it fixes the actual symptom," closing the loop Finding 1 opened.

**Step 4 — optional, strengthens the result further.** Repeat Step 1's baseline hang
reproduction one more time afterward (reboot, cold load, Doom, no poke) to confirm the
hang still happens *without* the poke in the same session/hardware state — ruling out
"something else about today's boot just happened to fix it."

## What a negative result would mean

If the hang still occurs after the poke, that doesn't necessarily kill the Master Clear
theory outright — it would mean either: the poke's target address is wrong (worth
double-checking the PCI `Find Device` call actually matches this specific card/slot, same
caution as every other script in this project), or the bug is a genuine state-corruption
issue that a single Master Clear pulse doesn't fully resolve (e.g. something order-dependent
in exactly how Duke Nukem 3D's more thorough init differs from a bare Master Clear), or the
real cause is somewhere else in `DSDMA.exe`'s state machine entirely. Worth treating a
negative result as new information to investigate, not just "theory disproven, drop it."

## Next step

Run this on the real X10SAE/YMF724 setup next time that hardware session happens. Until
then, this closes out the achievable static/dynamic analysis work in this repo — the
remaining open items (dispatch-table selector mapping, PCI Device-ID discriminator values
seen in `FUN_1059_a64f`) are lower priority and don't block this test.
