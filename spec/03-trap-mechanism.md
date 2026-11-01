# 3. Trap mechanism (`TRAP-`)

What must be intercepted, for which kinds of programs, and how the TSR shares the machine with a memory manager. This chapter
states **outcomes**. The original reaches them in one particular way, described under "Reference design" below and in
`DEC-3`; a replacement may choose another if it meets every requirement here.

## 3.1 Coverage

- **TRAP-1** `MUST` `verified` `F15 F16 E16` - Intercept DMA-port accesses made by real-mode and V86-mode DOS programs. Observed in E16: a V86 `IN AL,02` after load faults into the TSR and returns to the program at the next instruction.
- **TRAP-2** `MUST` `verified` `F19 F20 E19 E20` - Intercept DMA-port accesses made by **32-bit DOS-extender programs** (tested: DOS/4GW, PMODE/W, DOS/32A). A program running in protected mode with full I/O privilege reaches the hardware directly and is never intercepted: E19 run 1 shows a plain VCPI protected-mode client is not trapped by the I/O permission bitmap, by Jemm's own traps, or by QPIEMU callbacks.
- **TRAP-3** `MUST` `verified` `F19 E19` - Therefore, after the TSR has loaded, no protected-mode DOS program may be able to run with unrestricted port access. The original achieves this by making VCPI unavailable to later programs (it answers the VCPI presence check, INT 67h AX=DE00h, with AH=84h "not present") and by becoming the DPMI host the extenders find instead (chapter 4).
- **TRAP-4** `MUST` `verified` `F19 F20 E20` - Extenders that look for a DPMI host through INT 2Fh AX=1687h must find the TSR's host and run under it with their normal behaviour (chapter 4).

## 3.2 Sharing the machine

- **TRAP-5** `MUST` `verified` `F15 F16` - Load **on top of** a VCPI-providing memory manager and leave it working. Tested: Jemm 5.86 only. EMM386 and QEMM are untested (`TRAP-12`).
- **TRAP-6** `MUST` `verified` `F15` - Take faults before the memory manager does, and hand on every fault the TSR does not own (`EMU-8`). Observed: the TSR's handler is ahead of Jemm's in the interrupt table, and Jemm's own port traps (it already traps most of the DMA ports for its virtual DMA) continue to work for the other channels.
- **TRAP-7** `MUST` `verified` `F15 F16` - Leave the memory manager's A20 handling, PIC base addresses and existing port traps as they were, and make every port in `EMU-1` fault, **adding to the I/O permission bitmap only the ports the manager does not already trap**. Observed in E16 with Jemm 5.86: Jemm already traps 00-07, 0A-0F, the page registers 81, 82, 83, 87, 89, 8A, 8B, C4-C7, D4, D6 and D8-DE (plus 64 and 92 for A20), and the original adds only 08, 09, C0, C2, D0, D2 and the PIC ports 20, 21, A0, A1. Another manager may trap a different set, so a replacement must not assume Jemm's.
- **TRAP-8** `SHOULD` `inferred` `F15` - Remember which bitmap bits the manager had set before the TSR changed them, so that removing a trap (for an unload command, `LIFE-8`) restores the manager's setting instead of clearing a bit the manager needs. The original keeps such a shadow.
- **TRAP-9** `SHOULD` `verified` `F17 F20 E20` - Work when QPIEMU (Jemm's port-trap interface) is loaded **before** the TSR. E20 run B does. The reverse order (TSR first, then QPIEMU) made a V86 DMA probe hang in E20 run C; the cause is not understood, so a replacement SHOULD not hang in that order but this is not required.
- **TRAP-10** `MUST` `verified` `F15 F16` - Keep all other I/O at full speed: only the listed ports fault (`EMU-1`).
- **TRAP-11** `MUST` `inferred` `F15` - Resume the interrupted program with its interrupt-flag and other state as it was at the fault, through the memory manager's normal return path. The original's return path was only partly stepped through (E16 shows the program resuming at the next instruction with the expected register values).
- **TRAP-12** `SHOULD` `untested` `F20` - Validate under EMM386 and QEMM. Neither has been exercised.

## 3.3 Reference design (non-normative)

The original works as a "hypervisor-lite" stacked on the VCPI server: it learns the server's page directory, descriptor tables and task state through VCPI, switches to protected mode, sets bits in the server's I/O permission bitmap for the DMA ports, patches the server's general-protection and page-fault handlers to point at its own stubs, and then installs its DPMI host. It does not use QPI, HDPMI's trap interface or any memory-manager API. (F15, F16, F21)

Alternatives and their status, none chosen (`DEC-3`):

| Option | Covers V86 | Covers 32-bit extenders | Status |
|---|---|---|---|
| Original design: stack on VCPI, edit server tables, own DPMI host | yes | yes (through its DPMI host) | verified |
| Jemm QPI (port-trap callbacks) | yes | **no** (E19, E20 run D shows 0 callbacks) | verified; useful for diagnostics only |
| HDPMI's port-trap API | no | yes (HDPMI hosts only) | untested; requires the extender to use HDPMI |
| System-management-mode trap in firmware | yes | yes | untested; platform-specific |
