# Finding 5 — the real init sequence, the D-DMA enable write, and the dispatch mechanism

**Date**: 2026-10-07
**Method**: Ghidra, tracing cross-references from the real entry point (`1059:bcbd`) and
from the hardcoded-defaults function found in Finding 4. Scripts:
`tools/ghidra_scripts/TraceInit.java`, `TraceDefaultsCallerAndDispatch.java`. Raw outputs:
Ghidra script output (not shipped; see `docs/reproducing.md`).

## The hardcoded defaults ARE live, reachable code — not a self-test

Finding 4 left open whether the `1059:014c` block (`[0x7176]=0x220`, `[0x717b]=5`,
`[0x7178]=1`, `[0x7174]=0xF390`) was a real default path or an unreachable/self-test
block. **Resolved: it's reachable.** Call chain: `FUN_1059_a831` → `FUN_1059_a64f` (at
`1059:a675`) → the defaults function. `FUN_1059_a64f` itself is genuine init logic (see
below), so these are real compiled-in defaults that participate in actual startup, not dead
code.

## `FUN_1059_a64f` — command-line parsing, PCI BIOS probe, and the actual D-DMA enable write

Read the first 60 instructions in full. In order:

1. **`INT 21h, AH=62h`** — Get PSP (current process) segment, then reads the command-line
   tail length byte at `ES:[0x80]` (standard DOS PSP layout) and null-terminates it —
   **this is command-line argument parsing** for `DSDMA.exe` itself.
2. **`INT 1Ah, AX=B101h`** then `CMP EDX,0x20494350` — the exact PCI BIOS installation
   check (`'PCI '` signature) used throughout the earlier notes' `DEBUG.COM`
   scripts. Confirms `DSDMA.exe` does its own independent PCI BIOS presence check, not
   relying on `SETUPDS` having already done it.
3. **`INT 1Ah, AX=B109h` (Read Config Byte), `DI=0x8`** then again with **`DI=0x2`** —
   reads PCI config offsets `0x8` (Revision ID) and `0x2` (Device ID low byte), then
   compares the result against `0x1`, `0x2`, `0x4`, `0xA` — almost certainly discriminating
   between specific YMF724-family chip revisions/device-ID variants to decide how to
   proceed. Not fully enumerated which values map to which chip.
4. **`INT 1Ah, AX=B109h`, `DI=0x40`** — reads PCI config offset `0x40`, tests bit 0
   (`TEST CX,0x1`).
5. **Builds a new control value**: `AND CX,0xff3f` (clears bits 6–7) then
   `MOV AL,[0x7178]` (the DMA-channel variable — `1` by default) `; SHL AL,0x6 ; OR CL,AL`
   (packs the channel number into bits 6–7) `; OR CL,0x1` (sets bit 0).
6. **`INT 1Ah, AX=B10Ch` (Write Config Byte), `DI=0x40`** — writes the constructed value
   back to offset `0x40`.

**Correction (2026-10-07, resolved via the real YMF724F datasheet, see `docs/datasheets.md`,
confirmed from `ftp.icm.edu.pl/Linux/alsa/manuals/yamaha/ymf724.pdf`)**: step 6 above is
**not** the D-DMA enable — offset `0x40-41h` is the **Legacy Audio Control** register
(default `907Fh`), whose bit 0 is `SBEN` (Sound Blaster Enable) and whose `SDMA` field
(legacy SB-compatible DMA channel, for the chip's own SB16-emulation block) sits right
where the disassembly packs `[0x7178]`'s channel number. So this step enables the chip's
**legacy SB-compatibility decode** and tells it which DMA channel a DOS game's `BLASTER`
variable will use — a real and necessary step, just not the D-DMA step. Reading further
into the same function (`FUN_1059_a64f`, continuing past instruction 60) finds the actual
sequence, and it's worth presenting in full because every step now matches the datasheet
exactly:

```
1059:a706  MOV AX,[0x7176]          ; legacy SB port variable (0x220 default)
1059:a709  CMP AX,0x240 / 0x260 / 0x280 / (else 0x220)
...        -> DX = 0x0/0x4/0x8/0xC  ; the SBIO field's 2-bit select code, pre-shifted into position
1059:a730  MOV AX,0xb109; MOV DI,0x42; INT 1Ah      ; Read Config Word, offset 0x42
1059:a738  AND CX,0xe7ff                             ; clear SMOD (bits 12:11)  [corrected, Finding 13]
1059:a73c  OR CX,0x1000                               ; SMOD (bits 12:11) = 10b = Distributed DMA  [corrected, Finding 13]
1059:a740  OR CX,DX                                   ; OR in the SBIO select code
1059:a742  MOV AX,0xb10c; MOV DI,0x42; INT 1Ah      ; Write Config Word, offset 0x42

1059:a74a  MOV CX,word ptr [0x7174]  ; the D-DMA base-pointer variable (0xF390 default)
1059:a74e  AND CX,0xfff0             ; clear the low 4 bits (EA/TS/CE live there)
1059:a751  OR CX,0x1                 ; set bit 0
1059:a754  MOV AX,0xb10c; MOV DI,0x4c; INT 1Ah      ; Write Config Word, offset 0x4C <-- the real D-DMA enable

1059:a75c  MOV AX,0xb108; MOV DI,0x3c; INT 1Ah      ; Read Config Byte, offset 0x3C (Interrupt Line)
1059:a764  MOV byte ptr [0x717a],CL                  ; store the card's real assigned IRQ
1059:a768  XOR AX,AX; RET                            ; success
1059:a76b  STC; MOV AX,0xffff; RET                   ; error path
```

This matches the real datasheet precisely, register by register:
- **Offset `0x42-43h`** is "Extended Legacy Audio Control," whose `SBIO` field (bits
  `[3:2]`) selects the legacy SB base address (`220h`/`240h`/`260h`/`280h`) — exactly the
  4-way branch computing `DX`, then OR'd into the cleared field. Confirms `[0x7176]` really
  is the legacy SB port variable, as Finding 4 already concluded.
- **Offset `0x4C-4Dh`** is "D-DMA Slave Configuration" — bit 0 is `CE` ("Channel Enable" —
  *"This bit enables the Distributed DMA function"*, default `0`), with the Base Address in
  the upper 12 bits. The disassembly's `AND CX,0xfff0; OR CX,0x1` is **exactly** "keep the
  base address bits, set CE=1" — this is unambiguously the real D-DMA master-enable step,
  packed into the same write as programming the base address from `[0x7174]`.
- **Offset `0x3Ch`** (Interrupt Line) gets read right after — the exact same register the
  the earlier notes' real-hardware session read directly via `DEBUG.COM` as a
  workaround once `YMFIRQ.exe` turned out to be a dead tool. **`DSDMA.exe` does this same
  read internally as a matter of course** — it was never relying on `YMFIRQ.exe` for this at
  all, which also explains why the earlier notes' real-hardware YMF724 win worked (IRQ 5 confirmed
  working) despite `YMFIRQ.exe` failing: `DSDMA.exe` gets the real IRQ itself.

So the earlier notes' original "offset `4Ch`" claim was correct all along — my first reading of
this function stopped one register too early and mis-identified the Legacy Audio Control
write as the D-DMA enable. Both writes are real and both matter; they're just different
registers serving different (adjacent) roles. Raw full-function dump:
Ghidra output of `FindDDMAEnableWrite.java` (not shipped; see `docs/reproducing.md`).

## How the 9 D-DMA accessor functions actually get called

Finding 4 found zero static callers for any of the 9 accessor functions. Searching the
whole program for indirect `CALL`/`JMP` forms found the likely explanation:

```
1059:035b  JMP word ptr CS:[BX + 0x360]      <- a genuine jump/dispatch table
1059:06a8  CALL word ptr [BX + 0x18]
1059:06d2  CALL word ptr [BX + 0x1a]
1059:12ba / 1343 / 1398 / 13ef / 145c / 14a3 / 14f0 / 153f / 15a4 / 15e3   CALL BX   (10 sites)
1059:11b9 / 1244   CALL AX   (2 sites)
1059:641c  CALL DX
```

The repeated `CALL BX` pattern (10 separate call sites, each presumably preceded by
loading BX with one of the accessor functions' addresses as a plain constant) is the most
likely explanation for why no direct references show up — the call target is a runtime
register value, not a fixed operand Ghidra's static reference scanner associates with the
destination. This matches Ghidra's own auto-naming of the VCPI-switch function as
`caseD_0` (its switch/case-table naming convention) — strong independent corroboration that
a dispatch-table structure really is in play here, consistent with a single generic
"drive the D-DMA register identified by this selector" entry point fanning out to the 9
accessor primitives.

**Resolved in Finding 15 (2026-10-09)**: the `CALL word [BX+0x18]`-style sites are a per-channel callback table (`0xC7B0`) driven by the trapped port handlers, which are in turn reached from the #GP handler's `IN/OUT` decoding. The original note follows.

**Not fully resolved (superseded)**: the exact selector value → accessor-function mapping, and whether
this dispatch is driven by the trapped I/O port number itself (which would be an elegant,
obvious design: trap port → compute register offset → dispatch to the matching accessor) or
by something else. Worth tracing if the project ever needs the complete call graph, but not
necessary for the Master Clear question — that's already settled at the "no such accessor
function exists at all" level (Finding 4), independent of how the existing ones get invoked.

## Updated status of the project's two headline questions

1. **Does `DSDMA.exe` skip Master Clear?** Still yes, now confirmed two ways (ndisasm +
   gap-filled Ghidra disassembly) and unaffected by this finding — there's no Master Clear
   accessor to dispatch to in the first place, regardless of dispatch mechanism.
2. **How does the D-DMA enable actually happen?** Now concretely and correctly answered:
   `FUN_1059_a64f` performs three PCI config writes in sequence — offset `0x40` (Legacy
   Audio Control: `SBEN` + `SDMA` channel field, enabling the chip's legacy SB
   compatibility), offset `0x42` (Extended Legacy Audio Control: `SBIO` field, selecting
   the legacy base address), and offset `0x4C` (D-DMA Slave Configuration: `CE` bit +
   base address, the actual Distributed DMA enable) — then reads back offset `0x3C`
   (Interrupt Line) to get the card's real assigned IRQ directly, rather than relying on
   `YMFIRQ.exe`. Every one of these matches the real YMF724F datasheet exactly.

## Next step

The D-DMA enable mechanism and the init call order are now fully resolved. Remaining
candidates: (a) complete the dispatch-table trace (low priority, doesn't change the Master
Clear conclusion), or (b) move to Phase 3 (DOSBox-X dynamic verification) — the Master
Clear absence is already as resolved as static analysis can make it; dynamic verification
is what would actually prove the warm-up-bug causal link by comparing a cold-load port
trace against a post-warm-up one.

## Correction (2026-10-08, Finding 13)

The `AND CX,0xE7FF` / `OR CX,0x1000` pair at `1059:a738/a73c` does **not** touch the SBIO
field. Bits 12:11 of offset `0x42` are **SMOD** ("SB DMA mode": 0 = PC/PCI, 2 = Distributed
DMA — YMF724F datasheet p.19). The pair clears SMOD and sets it to `10b`, i.e. DSDMA
**switches the card's SB DMA protocol to Distributed DMA** in the same register write that
selects the SB I/O base. The SBIO select code (`DX` = 0/4/8/C, bits 3:2) is OR'd on top.
