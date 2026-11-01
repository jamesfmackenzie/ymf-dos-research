# Finding 17 — QPIEMU vs Jemm's own DMA port traps (can a QPI client take over ports 00-0F, 81-8B, C4-DE?)

**Date**: 2026-10-10
**Basis**: DOSBox-X 2026.10.01 (core=normal, Pentium) + FreeDOS 1.3 + `DEVICE=\JEMMEX.EXE V`
(Jemm 5.86), then `JLOAD QPIEMU.DLL` (QPIEMU 1.2, QPI version reported 0703). **`Dsdma.exe` not
loaded.** Test program `experiments/17-qpiemu-port-overlap/src/qt.asm` (real-mode .COM, modelled on Jemm's
`JLM/QPIEMU/Test/TESTDMA.ASM`); logs in `experiments/17-qpiemu-port-overlap/results/`. Jemm source from the local checkout
(a local Jemm source checkout) used to explain results.
Tags: **verified** = observed in this run; **source** = read in Jemm source, consistent with the
run; **inferred** = reasoning only; **not tested**. DOSBox-X has no D-DMA slave and runs
no real PCI hardware, so only the trap/delivery layer is tested, not audio DMA.

## Short answer
Yes. A QPI client can take over every port Jemm already traps for its VDMA, with two limits:
**channel 2's mask/mode ports stay with Jemm**, and **REP string I/O arrives as one callback
with no usable count**. Pass-through to the real 8237 via `1A04h` works.

## Results
| Question | Result |
|---|---|
| `1A09h` on Jemm-trapped ports 02, 03, 83, 0A, 0B, 0C, 0F, C4 | **verified** CF=0 on all. |
| `1A09h` on ports Jemm does not trap: 08, 09, C0, D0 | **verified** CF=0 on all (QPIEMU sets the IOPB bit itself). |
| `1A09h` twice on the same port | **verified** second call CF=1 (matches `Install_IO_Handler` rejecting a non-zero slot; **source** `Tools/JLOAD/VMM.ASM`). |
| `1A0Ah` untrap | **verified** CF=0 for all. After untrapping port 02, `IN AL,02` reaches Jemm again (no callback, AL merged into EAX normally). |
| Callbacks per instruction | **verified** exactly **1** for every instruction on every trapped port: byte/word/dword IN/OUT, single `INSB/OUTSB`, `REP INSB/OUTSB/INSW/OUTSW`. Word/dword are **not** split into bytes. |
| Callback register contract | **verified** DX = port, CH = 02 (IF was set; QPIEMU clears client IF/TF during the call), CL = type: bit2 OUT, bit3 word, bit4 dword, bit5 (0x20) string, bit6 (0x40) REP. Observed CL: `00/08/10` IN b/w/d, `04/0C/14` OUT b/w/d, `20` INSB, `24` OUTSB, `60/68` REP INSB/INSW, `64/6C` REP OUTSB/OUTSW. EAX = the client's EAX (OUT value in EAX/AX/AL by size). |
| REP string I/O | **verified** one callback for the whole `REP`; **CX at entry holds the type flags, so the repeat count is not visible** (ECX high half is stale client data, e.g. 0001). SI/DI are the client's. After the callback the client's CX/SI/DI are unchanged (CX=3 stayed 3, SI/DI not advanced) and execution continues after the instruction. A callback therefore cannot implement `REP INS/OUTS` correctly (source: `iocb` in `QPIEMU.ASM` overwrites `Client_ECX` low word, restores it afterwards). **inferred**: DOS/Doom-style code that uses REP OUTSB to a trapped DMA port would get wrong results. Sound-card DMA code in practice uses single `OUT`s to these ports. |
| IN result | **verified** the callback's returned EAX replaces the client's **whole** EAX (a callback returning A5A5A5A5 turned 11111111 into A5A5A5A5 after `IN AL`); Jemm's own handler (after untrap) preserved the upper bits (11111134). A QPI callback must merge into AL/AX itself. |
| Does `1A04h` reach real hardware? | **verified** (DOSBox-X's 8237): in passthrough mode the callback forwarded ch1 programming (flip-flop clear, address 34 12, count FF 00, page 5A) and the readback was 1234 / 00FF / 5A. **source**: `1A04` calls `Simulate_IO`, which goes straight to hardware (v5.84 note: it no longer re-enters `IO_Trap_Handler`), so Jemm's VDMA is bypassed. |
| `1A00h/1A01h` vs normal `IN` | **verified** `1A01h` write 3C to 83/82/87 then a normal `IN` returns 3C, same as `1A00h`. **Cannot distinguish** "reaches HW" from "reaches Jemm VDMA", because Jemm does not shadow page-register reads here. |
| Does Jemm's DMA translation still run on ports we own? | **Partly.** **verified** for channel 2: `OUT 0B,56` (ch2 mode), `OUT 0A,02` (unmask ch2), `OUT 0A,06` (mask ch2) produce **0 callbacks**; Jemm's `ISA_DMA_Traphandler` handles them first. Channels 0, 1, 3 (`0B,55/54`, `0A,00/01/04/05/07`) and `0F,0F` are delivered to us. **source** (`VDMA.ASM` 340-423, `?ALT_TRAPHDL` in `JEMM32.INC`): runs for OUT to 0A/0B/0C/0F, ch2 only, only while `DmaChn[2].cDisable==0`; its own comment says ports 04/05/81 for ch2 are *not* checked. Port 0C (flip-flop) was delivered to the callback with value 55. Page/address/count for ch1 (02, 03, 83) are delivered to us and Jemm never sees them. |
| Option to disable Jemm's DMA trapping | **source** none at runtime. JemmEx options are A20/NOA20, B=, D=nnn (buffer size only), EMX, FASTBOOT, I=, LOAD, MIN/MAX, MOVEXBDA, NOCHECK, NODYN, `SB` etc. (`Readme.txt`); `?DMAPT/?VDS/?MMASK/?ALT_TRAPHDL` are build-time. A VDS client can set `cDisable` per channel (not tested). Not tried at runtime since none apply. |
| Overhead | **verified** exactly 1 callback (one nested V86 execution) per trapped instruction. Timing under DOSBox-X (BIOS ticks, 55 ms; untrapped OUT 80 x1,000,000 = 15 ticks, ~0.8 us each; OUT 81 Jemm VDMA x100,000 = 7-11 ticks, ~4-6 us; OUT 08 via QPI callback x100,000 = 4-8 ticks, ~2-4 us). **Caveat**: emulator timing, coarse and noisy, not representative of real V86 fault cost; at best: same order of magnitude as Jemm's own trap, and the 16-bit callback counter wrapped (D40h = 200,000 mod 65,536). |

## What this means for Finding 15, recommendation 2
Taking over the DMA ports via QPIEMU is feasible and does not need Jemm's cooperation, so the
collision question is closed for channels 0/1/3. Added constraints:
1. Channel 2 (floppy) mask/mode is still serviced by Jemm; choose the YMF724 DMA channel
   among 0, 1, 3 (the default is 1).
2. A QPI callback cannot implement REP INS/OUTS (count not delivered); the generalized master
   must treat string I/O to its ports as unsupported, or find another way (e.g. Dsdma's own
   #GP decoder sees the real registers).
3. Callback must merge IN results itself; use `1A04h` for pure passthrough to hardware.
4. Everything here is **Jemm + QPIEMU only**. It says nothing about EMM386/QEMM (real QPI), and
   Finding 15's approach depends on the VCPI server's TSS/IDT layout, only verified on Jemm.

## Not tested
- `REP OUTSD`: hangs the run even on port 80 with no trap anywhere (`qt-S-control.txt`), so it
  is a DOSBox-X V86 issue (or my test), not QPIEMU; `qt-R-rep-outsd-hang.txt` is the same
  instruction on port 02. Dword string I/O is therefore unverified.
- Passthrough of string I/O via `1A04h` (count not available to the callback, so not attempted).
- VDS `cDisable`, EMM386/QEMM, real hardware, DMA with a non-contiguous buffer through Jemm's
  translation, Dsdma and QPIEMU loaded together.
