# Finding 3 — VCPI's reliability case vs. SBEMU, and real-mode/protected-mode compatibility

**Date**: 2026-10-07
**Status**: mostly architectural analysis + synthesis with existing earlier-notes/real-hardware
results, not new disassembly. Clearly marked below which claims are confirmed by this
session's RE work, which are confirmed by the earlier notes' real-hardware testing, and
which are informed inference not yet directly traced in the disassembly.

## Why VCPI is a structurally better foundation than SBEMU's DPMI-host trapping

SBEMU/VSBHDA's fragility (see the earlier notes' background section) comes from
*where* they intercept: a specific DPMI host (Crazii's HDPMI fork, or the
upstream-patched HX) has to be the one actually running under the game, and the game's own
extender has to either load that host or attach to an already-resident one via
`INT 2Fh,1687h`. Any extender that insists on its own private DPMI kernel regardless is
simply unreachable — not a bug, a structural dead end.

`DSDMA.exe` (confirmed via Finding 1) intercepts one layer lower: **VCPI**, provided
directly by the memory manager (EMM386/JEMM386/QEMM) as a side effect of giving any V86-mode
program access to extended memory — not by a competing DPMI implementation. It installs
itself resident, via VCPI, before any game or its extender loads. That means it doesn't
matter which DPMI host or extender the game uses afterward — the trap sits below that whole
layer, on infrastructure almost every DOS session already needs loaded anyway (XMS/EMS).

There's also a smaller "fakery surface": SBEMU has to emulate the *entire* SB16/AdLib
protocol stack in software (DSP commands, resampling, mixing) because there's no real SB
hardware at all behind it. `DSDMA.exe` only has to fake the DMA controller's bus-mastering
redirection — the YMF724 itself is real silicon doing the actual synthesis/playback once it
receives correctly-framed commands via its D-DMA slave registers (confirmed structure in
Finding 2). Fewer moving parts to get wrong, in principle.

**Update (Finding 15, 2026-10-09)**: the trap mechanism is now traced. After the
`DE0Ch` entry, `Dsdma.exe` sets bits in the VCPI server's own **TSS I/O permission
bitmap** for the 8237 ports (including page regs 81-8B) and patches the server's **IDT
vector 13 (#GP) gate in place**; its #GP handler decodes `IN/OUT/INS/OUTS` and emulates
them. The trap sits in the VCPI server's tables, so it is coupled to that server's TSS/IDT layout.
See Finding 15.

**Correction (Finding 19, 2026-10-10): the extender-agnostic argument above is WRONG.** A VCPI
client runs in its own CR3/GDT/IDT/TSS at CPL 0 (Jemm `VCPI.ASM` DE0C loads the client's tables), so
the server's IOPM and #GP gate are never consulted: verified, a VCPI PM client's port I/O is not
trapped. `Dsdma.exe` gets around this by hiding VCPI (its INT 67h hook answers DE00 with AH=84h) and
acting as a DPMI 0.90 host (INT 2Fh/1687h), so DOS/4GW-class extenders run as ring-3 DPMI clients
under its IOPM. It does depend on which extender/host the game uses; it just wins the race to answer.

## Does the trapping mechanism require anything resident? (recap, already answered)

Yes, two things, concurrently, for the whole session:
1. **A VCPI-providing memory manager** (EMM386/JEMM386/QEMM/386MAX), loaded first in
   `CONFIG.SYS` — this *is* the V86 execution environment; without it, `DSDMA.exe`'s
   `INT 67h` call has nothing to answer it.
2. **`DSDMA.exe` itself as a TSR**, loaded via `AUTOEXEC.BAT`/`LOADTSR.BAT`, staying
   resident — it's the thing standing in for chipset DMA hardware in real time, not a
   one-shot config step.

By contrast, the bridge subtractive-decode fix and the card's `SETUPDS` address
configuration are one-shot PCI-config-space pokes — nothing needs to keep running for
those. And critically, nothing about the game's own DOS extender/DPMI host needs to be any
particular thing, which is the whole point of the comparison above.

## Real-mode vs. protected-mode games

**Real-mode games — essentially no extra risk.** Once a V86 monitor is loaded, there is no
"true real mode" left on the CPU — every DOS program, extender or not, executes as a V86
client of that monitor. A real-mode game's port I/O is subject to the exact same
V86-level interception `DSDMA.exe` installed for itself; there's no second gatekeeper in
the picture.

**Protected-mode (DPMI) games — works, but with one named risk category.** A DPMI host
(CWSDPMI, DOS4GW's bundled host, PMODE/W, etc.) commonly becomes a VCPI client itself to set
up its own protected-mode environment on top of the memory manager. VCPI formally allows
multiple clients, but 1990s extenders were inconsistent about correctly chaining onto an
*already-resident* VCPI client rather than assuming they're the only one. That's the actual
risk: not "protected mode" as a category, but "does this specific DPMI host coexist cleanly
with a VCPI client that grabbed the interface first." `DSDMA.exe` is always in the better
position here, since it loads resident at boot, before any game's DPMI host initializes —
the late arrival has to chain onto it, not the reverse.

**Empirical validation already in hand** (from the earlier notes' real-hardware session,
all under DOS4GW):
- **Doom** — confirmed fully working end-to-end (after separately root-causing the
  demo-end hang, which was the Master Clear/warm-up issue, not a VCPI-chaining problem).
- **Duke Nukem 3D** — confirmed fully working, FM and digitized audio both.
- **Quake** — **open loose end, worth revisiting through this lens.** The session's photo
  log has a "Quake SNDDMA Init Failed Error" entry with no follow-up root-cause
  investigation in the text (unlike Doom's hang, which got a full writeup). Quake also runs
  under DOS4GW — the same extender as Doom — so if this *were* simple VCPI-chaining
  incompatibility, it's odd Doom didn't hit it too. More likely explanations to check first:
  the same warm-up/uninitialized-register-state issue manifesting differently in Quake's
  own DMA init check, or something specific to Quake's sound init sequence unrelated to
  VCPI at all. **Not yet diagnosed — flagged as a concrete next test**, now that
  "VCPI-chaining conflict" is a specific, checkable hypothesis rather than an unexplained
  error.

## What would distinguish a VCPI-chaining failure from the Master-Clear bug, if hit again

Useful operationally, for triage when testing further games/extenders: a VCPI-chaining
conflict should show up as a hang/crash/non-detection right at the game's own
protected-mode *initialization* (before any sound code runs at all), since that's when the
second DPMI host is itself trying to claim VCPI/set up its environment. The Master Clear
bug, by contrast, only manifests *after* sound has already partially worked — mid-session,
at a specific transition (Doom's demo-end) — because it's about DMA register state, not
about whether the protected-mode environment came up at all.

## Related

- Finding 1 (`01-ndisasm-first-pass.md`) — confirmed VCPI entry call, D-DMA accessor library.
- Finding 2 (`02-comparison-vs-piix4-spec.md`) — register-by-register match vs. the PIIX4
  spec, and the Master Clear gap this finding's "distinguishing the two failure modes"
  section depends on.
- Earlier notes (unpublished): the original SBEMU/VSBHDA
  background section this finding's comparison directly extends with a concrete mechanical
  reason, and the source of the untraced Quake `SNDDMA Init Failed` photo caption.
