# Finding 2 — DSDMA.exe vs. the Intel PIIX4 D-DMA spec, side by side

**Date**: 2026-10-07
**Baseline**: `docs/piix4-ddma-reference.md` (Intel 82371AB §8.5.2).
**Against**: `findings/01-ndisasm-first-pass.md`'s ndisasm pass.

## What matches the spec exactly

> **Correction (2026-10-07, see `findings/04-ghidra-corroboration.md`)**: the row below
> claiming a two-base-pointer structural match is **wrong** and kept here struck-through for
> the record. Ghidra's disassembly of the init routine shows `[0x7176]` is initialized to
> `0x220` — the legacy Sound Blaster port — not a second D-DMA base pointer. There is only
> one D-DMA base (`[0x7174]`). Everything else in this document stands.

| Spec behavior | DSDMA.exe evidence | Verdict |
|---|---|---|
| ~~Two separate base pointers, one for channels 0–3 (`DDMABP` @ `92h`), one for 5–7 (`94h`)~~ | ~~Two base variables, `[0x7174]` and `[0x7176]`~~ | **Retracted — see correction above.** `[0x7176]` is the legacy SB I/O base (`0x220`), unrelated to D-DMA. |
| Status Register read = chipset merges a read from the real 8237 *and* a read from the peripheral ("PIIX4 uses the data obtained via the read cycles... along with the value in the 8237") | Function at `0x5C6`: reads hardcoded real port `0x08` (DMA1 status), reads peripheral `base+8`, ANDs/ORs them together via a mask byte at `[0x7179]` | **Matches exactly.** This is a direct software reimplementation of the documented merge algorithm, not an approximation — DSDMA.exe is really acting as the chipset here, querying the real 8237 the same way PIIX4 would. |
| Single Channel Mask / Clear Mask Command have no distinct peripheral register — chipset folds both into a Write-All-Masks write | Function at `0x641`: writes `base+0xF` but first does `shr al,2; and al,0xfe` — a bit-shuffle consistent with repacking a single-channel-style input into the Write-All-Masks bit layout | **Matches.** No separate accessor exists for Single Channel Mask either, which is exactly what the spec predicts — there shouldn't be one. |
| Base/Current Address at `+0h`/`+1h`, Word Count at `+4h`/`+5h`, Page at `+2h`, Mode at `+Bh` | Dedicated accessor functions at exactly those offsets (`0x5B6`, `0x591`, `0x5E6`, `0x62F`, etc.) | **Matches exactly**, offset-for-offset. |
| Word Count is read with a double-read-and-compare pattern in real chipset DMA controller programming (standard practice for any 16-bit counter that free-runs) | Function at `0x591` reads high-then-low, twice, and keeps whichever pair didn't roll over between reads | **Matches the general class of correct behavior** the spec implies is needed for a live counter — not something the spec states outright, but the right thing to do and DSDMA.exe does it. |

## Where DSDMA.exe necessarily diverges from the spec (by design, not by bug)

| Spec mechanism | DSDMA.exe's equivalent | Why it has to differ |
|---|---|---|
| PIIX4 issues a **PCI bus retry**, becomes bus master, performs the real cycle, lets the CPU's retried instruction complete — all at the hardware/bus level, invisible to software | DSDMA.exe uses **VCPI** (`AH=DEh,AL=0Ch`, "switch V86→protected mode") to install itself as a privileged handler that presumably traps the CPU's `IN`/`OUT` instruction directly (not yet traced which exact fault/vector does the trapping — likely a V86 monitor GP-fault callback, since that's the standard VCPI client pattern) | There's no PCI bus retry to issue in software — there's no bus-master hardware playing along at all on a modern chipset. The *contract* PIIX4 implements at the bus level, DSDMA.exe has to implement at the instruction-trap level instead. Same end result (CPU believes it's talking to a real 8237), structurally necessary divergence, not a shortcut or a bug. |
| Address formula bits `[5:4]` select the channel (`0,1/5,2/6,3/7` → `00,01,10,11`), applied at *access time* against a single shared base pointer per group | Not yet observed in the ndisasm pass — the accessor functions take the base variable as already-resolved; where/when the channel-number-to-bits[5:4] encoding happens (likely once, at `SETUPDS`-configuration time, baked into whichever of `[0x7174]`/`[0x7176]` gets used) hasn't been traced yet | **Open, not yet a confirmed divergence** — flagged here so it doesn't get lost. Needs the Ghidra pass to confirm whether channel selection is computed per-access or baked in once at setup. |

## Where DSDMA.exe falls short of the spec (the actual bug candidates)

| Spec register | DSDMA.exe accessor found? | Significance |
|---|---|---|
| **Master Clear** (`Base+chan+0xD`, write-only) | **No accessor exists anywhere in the binary** (exhaustively checked — see Finding 1) | This is the leading theory for the Doom-demo-end-hang warm-up bug. The spec treats Master Clear as a normal, necessary part of the register set (it's how a real 8237, and by extension its DDMA proxy, gets reset into a known state) — DSDMA.exe appears to just never offer a way to do this, which lines up with "whatever uninitialized state the registers start in persists until some other program's more thorough init happens to clear it as a side effect of its own real chipset accesses" (the Duke Nukem 3D "warm-up" effect). |
| **Request Register** (`Base+chan+0x9`, write-only) | **No accessor exists either** | Less clearly a bug — Request is for software/memory-initiated DMA requests, which may genuinely not apply to a sound card driving its own DMA via hardware events rather than CPU-issued requests. Still worth confirming rather than assuming, since "two registers both missing" could also just mean the accessor-library search missed a block (see Finding 1's disassembly-desync caveat). |

## Bottom line

DSDMA.exe is a faithful, deliberate reimplementation of PIIX4's documented Distributed DMA
*semantics* — not a rough approximation. Every register it does implement matches the
spec's exact offsets and, where the spec documents nontrivial merge/fold behavior (Status,
Write-All-Masks), DSDMA.exe reproduces that behavior precisely. That makes the one gap that
stands out — Master Clear — much more likely to be a genuine omission than "the whole thing
is sloppy so who knows." The spec treats Master Clear as an ordinary register with no
special caveat or fold-in rule (unlike Single Channel Mask), so there's no textual reason
in the datasheet itself for DSDMA.exe to have skipped it — which argues for an actual
implementation gap on Yamaha's part, not a subtlety of the protocol DSDMA.exe is correctly
avoiding.

**Still pending before this is "confirmed" rather than "strongly indicated"**: Ghidra
corroboration (ruling out flat-disassembly misalignment hiding a Master Clear write
elsewhere) and dynamic DOSBox-X verification (does a cold load's port trace actually differ
from a post-warm-up trace in exactly the way a missing Master Clear would predict?).
