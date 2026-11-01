# Finding 4 — Ghidra corroboration: Master Clear absence confirmed, two mysteries resolved

**Date**: 2026-10-07
**Method**: Ghidra 12.1.4 headless, `x86:LE:16:Real Mode:default` (Ghidra's native "Old-style
DOS Executable (MZ)" loader correctly identified the format and language — no manual
language override needed). Scripts in `tools/ghidra_scripts/`. Raw outputs:
Ghidra script output (not shipped; see `docs/reproducing.md`).

This directly answers Finding 1's open question #3 ("flat ndisasm pass could be
misreading data as code") and resolves both of Finding 1's other open questions along
the way.

## Headline: the Master Clear finding survives proper segmented disassembly

Ghidra's default auto-analysis (Function Start Search + recursive descent from the real
entry point) only found **5 of the 9** D-DMA accessor functions ndisasm identified in
Finding 1 — specifically, it missed all **four read-accessors** (Word Count read, Address
read, the Status-merge read, Page read) because they don't start with the
`PUSH BP; MOV BP,SP` prologue pattern Ghidra's heuristic keys on, unlike the five
write-accessors it did find automatically. This is exactly the kind of gap the Finding 1
caveat was worried about — so each missing function was explicitly force-disassembled
(`tools/ghidra_scripts/FillGapsAndRescan.java`) and the result checked against what ndisasm
had already shown.

**Result: every single accessor function Ghidra decodes matches ndisasm's reading
instruction-for-instruction**, at the exact same physical addresses. This is strong,
independent confirmation — Ghidra's disassembler had zero knowledge of the ndisasm pass
and arrived at byte-identical results via proper segmented decoding.

**Final, Ghidra-corroborated set of every offset ever added to DX/EDX anywhere in the
program**: `{0x2, 0x4, 0x5, 0x8, 0xb, 0xe, 0xf, 0xc0, 0xffff}`. **Still no `0x9` (Request)
and no `0xD` (Master Clear) anywhere.** The Master Clear finding from Finding 1 holds up
under much more rigorous checking than before.

**Residual caveat, smaller than before but worth stating plainly**: this confirms the
*known accessor-library cluster* has no Master Clear path, and that every other register
access in the whole program routes through this shared library (zero inlined `IN`/`OUT`
found anywhere outside it, in either pass). It would be a real stylistic anomaly for
Master Clear specifically to be special-cased and inlined somewhere else while every other
register goes through the shared helpers — but the full 53KB binary hasn't been
exhaustively disassembled end-to-end, so this isn't an absolute 100% proof, just a much
stronger version of Finding 1's claim.

## Mystery #1 resolved: `[0x7176]+0xE` is not a second D-DMA base pointer at all

Finding 1 flagged this as unclear — it looked structurally like a second DDMABP-style base
(mirroring the PIIX4 spec's two base pointers for channel groups 0–3 and 5–7), which Finding
2 cited as a point of structural similarity to the spec.

**That structural-match claim in Finding 2 was wrong.** Ghidra's disassembly of the init
routine (see below) shows `[0x7176]` gets initialized to **`0x220`** — the classic Sound
Blaster legacy I/O base address. `base+0xE` = `0x22E`, which is the real SB DSP's
"Read-Buffer Status" port, a well-known, unrelated register from the *legacy SB protocol*,
not the D-DMA register set at all. The function at this address is a simple status-port
poll, most likely a presence/sanity check (same spirit as the real-hardware DSP-reset-probe
technique used throughout the earlier notes' bring-up sessions), not part of the DMA engine.

**Correction to Finding 2**: there is only **one** D-DMA base pointer (`[0x7174]`), not two.
The "matches PIIX4's two-base-pointer design" row in Finding 2's comparison table should be
read as not confirmed / likely incorrect — worth fixing there too.

## Mystery #2 (new): hardcoded default register values match real-hardware `BLASTER` settings

Tracing the init routine (`1059:014c` onward) turned up something not previously known from
either the ndisasm pass or the earlier notes — a block of hardcoded constant writes:

```
1059:0150  MOV word ptr [0x7176],0x220    ; legacy SB port = 220h
1059:0156  MOV byte ptr [0x717b],0x5      ; = 5  (IRQ!)
1059:015b  MOV byte ptr [0x7178],0x1      ; = 1  (DMA channel!)
1059:0160  MOV word ptr [0x7174],0xf390   ; D-DMA base = F390h
```

**IRQ 5 and DMA channel 1 are exactly the values the earlier notes used throughout
its real-hardware YMF724 testing** (`BLASTER=A220 I5 D1 T4`, `LOADTSR.BAT`'s
`SET BLASTER=A220 I5 D1 T4`). This is either a genuine compiled-in default (used before
`ds.ini` is parsed, or as a fallback) or a self-test/known-configuration block — not yet
determined which. `0xF390` as a D-DMA base is a plausible-looking PCI-assigned I/O BAR value
for this era, but hasn't been confirmed as anything beyond "a hardcoded constant that
appears here."

**Open, not yet resolved**: what calls this function, under what condition, and whether
`0xF390`/these values are ever actually used for a real transfer or just exist for a
self-check. Worth tracing the caller(s) of `1059:014c` next.

## What else turned up tracing forward from the accessor cluster

The dispatcher function (ndisasm's "mystery" function at blob offset `0x665`, now confirmed
at `1059:00d5`) is a generic "read or write one byte via whatever's already in DX" helper —
`TEST ECX,0x200` / `CMP ECX,0x2` gate which of two paths (`OUT DX,AL` vs `IN AL,DX`) runs,
with an error path (`JMP 0x1000:1ec4`) for anything else. This is consumed by the
hex-digit-printing and DOS-character-output helpers immediately following it in the
listing (`1059:00ee` = `INT 21h AH=02` "print char" wrapper, `1059:00fc` = a hex-nibble
formatter) — i.e. this part of the cluster is **diagnostic/logging code**, not DMA-register
access, despite superficially looking like it belonged to the same family when read via flat
ndisasm.

## Updated picture vs. Finding 2

Finding 2's register-by-register comparison against the PIIX4 spec stands, **except**:
drop the "two base pointers matches the spec's two-group design" claim — there's only one
D-DMA base (`[0x7174]`); `[0x7176]` is an unrelated legacy-SB-port variable. Everything else
(Status-merge read matching the documented chipset+peripheral merge algorithm,
Write-All-Masks bit-folding, exact offset matches for Address/Word-Count/Page/Mode) stands
as originally written and is now additionally confirmed via independent Ghidra disassembly,
not just ndisasm.

## Next step

Trace the caller(s) of the `1059:014c` hardcoded-defaults function, and locate/trace the
actual init routine around `1059:bcbd` (the real entry point) and the dense
`INT 21h`/`INT 1Ah`/`INT 67h`/`INT 2Fh` cluster already spotted at `1059:c2xx`–`1059:c7xx`
in the Ghidra function/INT-site census (`InspectDsdma.java`) — this is where the actual decision
logic (detect VCPI, probe the card, parse `ds.ini`, decide whether/how to install) lives,
and where the call order into the accessor library (and thus the full picture of what does
and doesn't happen before the TSR goes resident) gets settled.
