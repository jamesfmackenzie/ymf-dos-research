# Finding 18 — SBEMU / VSBHDA source review: what can we borrow for the DMA trap layer?

**Date**: 2026-10-10
**Basis**: source read directly (shallow clones in gitignored `capture/sbemu/`; nothing copied into tracked files).
Tags: **verified** = read in source; **inferred** = reasoning; **not tested** = not run.

## Which upstream (verified)
| Repo | Commit | Notes |
|---|---|---|
| `Baron-von-Riedesel/VSBHDA` (maintained fork of SBEMU, same author as Jemm/HX) | `03cd6e0`, 2026-10-08 | Read in depth. Needs only Jemm (V86) or HDPMI. |
| `crazii/SBEMU` (original) | `1f88a77`, 2026-10-07 | Needs its own HDPMI fork and QPIEMU/QEMM; only skimmed (`qemm.c`, 347 lines). |

Recommendation: study/borrow from **VSBHDA** (the original's own issue #40 points users there).

## Q1 Licences (verified)
- Both repos: **GPL v2** (`LICENSE`/`COPYING`). SBEMU's `CONTRIBUTING.md` says GPL-2.0 **without** "or later".
- Source files (`PTRAP.C`, `VDMA.C`, `VSB.C`, `RMCODE1.ASM`) carry **no per-file licence header**; `DBOPL.CPP` carries the DOSBox GPL-2+ header. VSBHDA also bundles MPXPlay (sound hardware), DOSBox (OPL3/ADPCM) and TinySoundFont — irrelevant to us.
- Obligation: any TSR containing copied `VDMA.C`/`PTRAP.C` code becomes GPL-2.0-only and must ship source. Re-implementing from the *design* (clean room from the 8237 datasheet and Findings 15-17) avoids this. This repo is private research, so the choice only matters once we publish a binary.

## Q2 Port trapping (verified)
- `src/PTRAP.C` (520 lines). Detection: QEMM via `INT 67h AX=3F00h` (`CX='QE' DX='MM'`), else QPIEMU via `INT 2Fh AX=1684h BX=4354h` (VSBHDA writes a 3-byte `INT 2Fh; RETF` helper into PSP:005Ch to call the returned entry). Same entry we found in Finding 17.
- Registration: `PTRAP_AddRange(start, portmap, handlers)` — `MAXRANGES 8`, `portmap` is a bitmask of ports from `start`. V86 side: QPI `1A06` (get old callback), real-mode callback created in the DPMI host, `1A07` (set callback), `1A08` (save port state), `1A09` (trap each port). Same QPI calls we tested.
- Handler type is **byte-only**: `uint8_t (*)(uint16_t port, uint8_t val, uint16_t flags)` with `TRAPF_OUT=4`, `TRAPF_IF=0x200`. Word/dword/string forms are not handled — consistent with Finding 17 (QPI gives one callback per instruction, no REP count).
- `RMCODE1.ASM` (101 lines, 16-bit) is the V86 front stub copied to PSP:60h: a far routine that `jmp`s to the callback, with port 20h (PIC) handled inline by calling QPI `1A00/1A01` (untrapped I/O). Registers on entry: DX=port, CL=flags, AL=value; returns with `retf`. **This stub is exactly the shape a pure real-mode TSR needs.**
- Protected-mode clients are handled separately: `PTRAP_Install_PortTraps` also installs **HDPMI** port traps (`_hdpmi_install_trap`, max 8 ranges). Under Jemm only, with no DPMI host, PM games run on VCPI. Whether a QPI callback also fires for I/O faults from a VCPI-protected-mode client (DOS/4GW) is **unknown** — VSBHDA needing the HDPMI path for PM suggests it may not (**inferred**). Dsdma's IOPM/#GP hook covers that case regardless (Findings 15/16). **This is the biggest open risk for the QPIEMU-primary design**, since Doom and Duke3D are DOS/4GW titles.
- Known hazard: permanently trapping PIC port 20h locks some machines (ThinkPads T41/T61, VSBHDA #4); workaround is a dynamic-trap build (`RMPICTRAPDYN`). We do not need port 20h.

## Q3 8237 emulation (verified, `src/VDMA.C` 449 lines + `DMA.H` 50)
- State: one struct `vdma`: per-bank (low/high) `PosCntRegs[4]`, `Base`, `MaxPos`, `CurPos`, `PageRegs`, `FlipFlop`, `DelayUpdate`; plus `Modes[8]`, `Masked` (own mask bitmap — the hardware multimask read is judged unreliable), `Complete` (terminal count), `Virtualized`.
- Only the **SB channels** are "virtualized" (`VDMA_PortTrap(ldma, hdma)`): address/count ports for that one channel (`AccPosCnt`), the matching page port (`AccPage`), and **all of 08-0F** (`Acc080F`). Everything else (other channels' address/count, other pages) is not trapped and runs natively.
- Flip-flop is per bank and toggled on every virtualized addr/count access; clear on 0C and 0D. Mask/mode/mask-reset/multimask on 0A/0B/0E/0F update `Masked`/`Modes`; 08-0F writes are then also passed to the real hardware (`UntrappedIO_OUT`) — so channel-2 mask/mode writes *do* reach the real controller. Reads of 08 splice the virtual terminal-count/DREQ bits into the real status.
- Channel 2 / REP: no special handling. Byte-only handlers, so a REP OUTSB/INSB or word write is not decomposed (**inferred** from the handler type; not run).
- Important difference from our goal: VSBHDA's DMA model is **virtual** — the SB channel never reaches a real 8237 or D-DMA slave; the driver reads the guest buffer itself. We need the *opposite*: keep the same state tracking but forward the programmed address/count/page/mode/mask to the D-DMA slave.

## Q4 Position readback and auto-init (verified, `VDMA.C`, `SNDISR.C`)
- Positions are not read from hardware. The sound ISR calls `VDMA_GetBase/GetPos/GetCount`, copies the next chunk from the guest buffer, and calls `VDMA_UpdatePos(ch, bytes)`, which advances `CurPos`, sets `Complete` past `MaxPos`, and wraps to 0 if the mode's auto-init bit is set (`VDMA_IsAuto`). The guest's own reads of address/count return the *virtual* current values (with a `DelayUpdate` trick when the flip-flop is mid-byte).
- For us: position/auto-init is the D-DMA slave's job (Finding 5/6/13). Only the register-programming half applies. Page writes reset `CurPos` (marked `???` in source).

## Q5 Separable modules, toolchain, mode
| Module | Lines | Reusable? |
|---|---|---|
| `PTRAP.C/H` | 520+ | QPI detect/trap/untrapped-I/O logic reusable as a reference; wired to DPMI RM callbacks and HDPMI, so it needs rewriting for a real-mode TSR. |
| `RMCODE1.ASM` | 101 | Closest to drop-in (V86 callback stub). |
| `VDMA.C` + `DMA.H` | 449+50 | State-machine ideas reusable; depends on `VSB_GetDMA/VSB_Running`, `UntrappedIO_*`, `PTRAP`, DPMI mem mapping. |
| `VSB.C`, `SNDISR.C`, `VOPL3`/`DBOPL`, `VMPU`, `TSF`, `ADPCM`, `hw/*` | thousands | Leave behind. |
- Toolchain: Open Watcom 1.9/2.0 + JWasm/JWlink (Makefile, `OW16.mak`, Linux variants) or DJGPP 2.05. Mode: **32-bit DPMI client** (HDPMI32i) or a 16-bit PM build (HDPMI16i); V86 trapping via Jemm. It is **not** a real-mode/VCPI TSR, so source cannot be dropped into one wholesale.

## Q6 Known issues (verified from issue titles/threads; not all read in full)
- Nothing mentions DMA ports, channel 2 or Jemm's VDMA conflicting with QPI traps. (VSBHDA never traps ch2 data ports; Jemm's ch2 mask/mode pre-emption only matters if the SB channel were 2.)
- Relevant: VSBHDA #4 (PIC port trap lock-up, above); crazii #212 (QPIEMU/HDPMI load order needs a delay on a Thinkpad X24 — timing/readiness hazard when stacking monitors); crazii #153 (SBEMU on a **YMF754** laptop: high-pitched noise — a *playback* issue in its audio path, not DMA trapping; shows Yamaha cards are only partially covered there). No YMF724/744 support in `hw/`.

## Conclusions
1. The strategy stands (QPIEMU primary, #GP/IOPM fallback), but "borrow SBEMU's DMA layer" should be read narrowly: borrow **ideas and ~150 lines' worth of structure** (trap registration, byte-port state machine, `RMCODE1` stub shape), not link against it. A clean re-implementation avoids GPL-2.0-only.
2. New top risk for the primary route: **does Jemm's QPI callback fire for DOS/4GW (VCPI-PM) I/O?** **Answered by Finding 19: no.** VCPI PM clients run at CPL 0 in their own tables and are not trapped at all; QPI callbacks also do not fire for HDPMI ring-3 clients. QPIEMU covers V86 programs only; PM games need a Dsdma-style DPMI-host/IOPM layer (or equivalent), so that part is mandatory, not a fallback.
3. Handlers must handle REP/word forms themselves or accept loss (Finding 17); VSBHDA ignores the problem.
