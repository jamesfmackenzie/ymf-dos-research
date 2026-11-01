# Finding 7 — real-hardware test session: inconclusive, but real new data

**Date**: 2026-10-08
**Status**: parked — not a clean confirm/deny, worth returning to rather than treating as
a dead end.

## What was run

Followed the `findings/06` protocol on the real X10SAE/YMF724 setup: root-port `SDE` fix
(Device 28/Function 5, same technique as `ROOTPORT.TXT` adapted for Function 5 — confirmed
success signature `AX=000B, CX=0001`, no keyboard freeze), `SETUPDS`, `LOADTSR.BAT`, then
Doom as the baseline/control.

## Result 1 — the Doom baseline stopped reproducing

Across several fresh cold-boot attempts (SDE fix → `SETUPDS` → `LOADTSR` → Doom, demo
played to end or Esc'd early), **the previously-reliable demo-end hang did not occur even
once**, and the poke (`MCLEAR.TXT`) was never applied in any of these attempts — this was
pure baseline/control testing. This removes the clean A/B comparison the protocol depended
on: there's currently no reliable "broken" state to compare a "fixed" state against for
Doom specifically.

**Two live hypotheses, neither confirmed**:
1. The bug is genuinely intermittent — plausible under the "uninitialized register garbage"
   theory itself: if Master Clear is skipped and whatever's left in the registers varies
   boot to boot, sometimes that garbage would happen to be benign. An intermittent hang is
   not evidence against the theory, just harder to test against.
2. Something about today's session differs from the original Oct 2026 bring-up (the user
   raised whether `BLASTER` is being set correctly via `LOADTSR.BAT` this time — plausible,
   but the patched `LOADTSR.BAT` that sets `BLASTER` on both branches was already in place
   during the *original* session where the hang reliably reproduced, so this doesn't cleanly
   explain the difference unless today's stick somehow doesn't have that same patched
   version. **Not yet confirmed either way** — next session should run `SET` after
   `LOADTSR.BAT` and check `BLASTER` directly, and diff today's actual `loadtsr.bat` against
   the patched version documented in the earlier notes.

## Result 2 — `MCLEAR.TXT` ran correctly, and surfaced a real new finding

The script executed cleanly (`AX=000B`-style success signature, `CX=F391` read back from
PCI config offset `0x4C`). Masked to `DX=F390` (base) then `+0xD=F39D` (the actual port
written).

**New finding, worth its own note**: `SETUPDS`'s own Configuration Menu displayed
`D-DMA BASE: 8000` — but the *live* PCI config offset `0x4C` value, read directly right
after `DSDMA.exe` loaded, shows base `0xF390`. That's `DSDMA.exe`'s own hardcoded default
from Finding 4/5, not the value `SETUPDS`/`ds.ini` configured. **This suggests `DSDMA.exe`
doesn't actually honor whatever base `ds.ini` specifies — it writes its own compiled-in
default to the card regardless.** Not yet traced further (would need to check whether
`ds.ini` genuinely contains `8000` and whether `DSDMA.exe` ever reads it at all, vs. always
using the hardcoded path from `1059:014c`) — a real, concrete loose end for a future static
analysis pass.

## Result 3 — Quake crashes, but probably not from the same bug

Quake was tested before and after the `MCLEAR.TXT` poke. **Both times it hit an identical
`Jemm386: exception 06` (invalid opcode) crash** — same register values
(`EAX=000000D9, EBX=00000050`), same faulting bytes (`F0 12 00 00 D1 FE 30 00`), same `CR2`,
byte-for-byte, before and after the poke. `IPX NOT DETECTED` printed immediately
beforehand. Despite the crash dump, execution continued afterward and printed what looks
like a normal, successful sound-init banner (`SOUND INITIALIZATION`, `USING DMA CHANNEL 1`,
`VERSION 3 SB STARTUP`, `SOUND SAMPLING RATE: 11025`) followed by a harmless
`MSCDEX NOT LOADED` warning.

**This is a different failure than the originally-photographed `"SNDDMA Init Failed"`
error** from an earlier session — a genuinely different crash
signature, not a repeat of the same symptom. Two things point toward this being unrelated
to the Master Clear question:
1. **Byte-for-byte identical crashes before and after the poke** — if this were
   DMA-register-state-dependent, some variation would be expected between runs.
2. **The crash happens early**, before the sound-init banner even prints — matching the
   "VCPI-chaining conflict" signature from `findings/03` (fails at/near protected-mode
   init) much better than the "Master-Clear-shaped, mid-session" signature Doom had.

**Not yet decoded**: what instruction is actually at fault (`CS:EIP=0000:00000017`). Would
need the actual Quake binary (not currently in this repo) to disassemble and confirm
whether this is IPX-detection code, DPMI/extender init, or something else. Worth doing if
Quake becomes the active focus again.

## Honest bottom line

This session didn't confirm or refute the Master Clear theory — the control stopped
reproducing (removing the clean comparison), and the one crash still reproducing (Quake)
looks like a separate bug unaffected by the fix either way. Not wasted effort: it surfaced
a real, previously-unknown discrepancy (`ds.ini`'s configured base vs. the live hardcoded
default) and ruled out one candidate explanation for Quake's crash matching the Master
Clear theory (the identical-crash-regardless-of-poke result is itself informative, just in
the negative direction for that specific hypothesis).

## Next steps, whenever this is picked back up

1. Confirm `BLASTER` is actually set correctly after `LOADTSR.BAT` this session (`SET`),
   and diff today's `loadtsr.bat` against the patched version in the earlier notes.
2. Run several more Doom baseline attempts (no poke) across fresh boots to get a rough
   sense of hang *frequency* rather than treating one session's non-reproduction as
   conclusive either way.
3. If `ds.ini` genuinely specifies `D-DMA BASE: 8000` and the card ends up at `0xF390`
   anyway, that's worth its own static-analysis pass — trace whether `FUN_1059_a64f`
   (or whatever calls it) ever reads `ds.ini`'s base value at all before falling through to
   the hardcoded default.
4. If/when returning to Quake specifically, get a copy of the exact Quake build being used
   into `samples/` and disassemble around the faulting address to settle whether this is
   IPX-related or DPMI/VCPI-related.
