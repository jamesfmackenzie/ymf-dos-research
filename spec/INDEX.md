# Requirement index

*Generated file. Do not edit by hand.*

146 requirements: 89 verified, 30 inferred, 27 untested.

| ID | Level | Evidence | Datasheet | Requirement | File |
|---|---|---|---|---|---|
| HW-1 | MUST | verified |  | Check for a PCI BIOS with INT 1Ah, AX=B101h (signature `PCI ` in EDX) and use the PCI BIOS read/write configuration functions (B108-B10Dh) | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-2 | MUST | verified |  | Find the card with INT 1Ah, AX=B102h for vendor `1073h`, device `000Dh` (YMF724F) | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-3 | SHOULD | untested |  | Also accept other YMF7xx family devices (for example YMF724, 740, 744, 754) once their configuration registers have been checked against the... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-4 | MUST | inferred |  | If there is no PCI BIOS or no matching card, do not install, print a message and return a nonzero exit code | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-5 | MUST | verified | DS-Y | **Legacy Audio Control (offset 40h)**: make sure `SBEN` (bit 0) is set and the `SDMA` field (bits 7:6) holds the Sound Blaster DMA channel (... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-6 | MUST | verified | DS-Y | **Extended Legacy Audio Control (offset 42h, word)**: read it, set `SMOD` (bits 12:11) to `10b`, which selects Distributed DMA, and set `SBI... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-7 | MUST | verified | DS-Y | **D-DMA Slave Configuration (offset 4Ch, word)**: write the slave base with its low four bits cleared, with bit 0 (`CE`, channel enable) set | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-8 | MAY | verified |  | Read the Interrupt Line register (offset 3Ch, byte) after the writes above | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-9 | MUST | inferred | DS-Y | Perform the configuration in the order 40h (if needed), 42h, 4Ch, then the read of 3Ch (if made), and finish it before the first trapped acc... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-10 | MUST | inferred |  | Change no configuration bit other than those of `HW-5` to `HW-7` (SMOD, the Sound Blaster enable, base and DMA channel fields, and offset 4C... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-11 | MUST | verified | DS-I | Use exactly these offsets for the registers in the "Yes" rows | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-12 | MUST | verified |  | Read the 16-bit **current word count** so that a count changing between the two byte reads cannot produce a torn value: read high then low t... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-13 | MUST | verified |  | Write address and count low byte first, then high byte | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-14 | MAY | untested | DS-I | Write **Master Clear (+Dh)** to the slave | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-15 | MAY | untested | DS-I | Write **Request (+9)** | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-16 | MUST | inferred | DS-Y | **Slave base.** The base written to 4Ch has its low four bits clear, so it is 16-byte aligned, and the slave occupies the 16 bytes from it (... | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| HW-17 | MUST | inferred |  | Access the slave with byte-wide port I/O, one register at a time, as the original does | [dsdma/01-card-interface.md](dsdma/01-card-interface.md) |
| EMU-1 | MUST | verified |  | Handle accesses to these ports: DMA1 00-0F, DMA2 C0-C7 and D0-DE (even ports), and the page registers 81, 82, 83, 87, 89, 8A, 8B | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-2 | MUST | verified |  | Redirect the **hooked channel** (section 0.4; `EMU-4`, `DEC-5`) to the slave | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-3 | MUST | inferred |  | Resolve which channel an access belongs to from the port (and, for the mask and mode ports, from the channel bits in the written byte), so t... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-4 | SHOULD | untested |  | Let the hooked channel be chosen on the command line (`LIFE-4`), not only fixed at 1 | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-5 | MUST | verified |  | Handle every I/O instruction form a program can use on these ports: `IN`/`OUT` with immediate and `DX` port, byte, word and doubleword sizes... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-6 | MUST | inferred |  | Treat a word or doubleword access to an 8-bit port as the equivalent run of byte accesses to consecutive ports | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-7 | MUST | inferred |  | After handling an access, resume the program at the next instruction (past prefixes), with registers and flags as the real instruction would... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-8 | MUST | inferred |  | If the faulting instruction is not one the TSR handles, or the port is not one it owns, do not consume the fault: pass it on to whatever han... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-9 | MUST | inferred |  | Keep the 8237 byte-pointer flip-flop of each controller (DMA1, DMA2) consistent between the TSR and the real controller | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-10 | MUST | verified |  | For the 8-bit hooked channel, compose the transfer address as the page register in bits 23:16 with the 16-bit address below it | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-11 | MUST | verified | DS-I | **Status read**: return the real controller's status for the channels it still owns, with the hooked channel's terminal-count and request bi... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-12 | MUST | inferred | DS-I | **Mask writes**: the slave has only a Write-All-Masks register | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-13 | MUST | verified |  | Preserve the guest's view of unrelated state: in the emulator run the temporary register and mask-all readbacks were identical before and af... | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-14 | MUST | verified |  | Not touch A20 or the keyboard controller and not remap the interrupt controllers | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| EMU-15 | MAY | untested |  | Avoid taking a fault for ports of unhooked channels where the memory manager does not itself need them | [dsdma/02-dma-emulation.md](dsdma/02-dma-emulation.md) |
| TRAP-1 | MUST | verified |  | Intercept DMA-port accesses made by real-mode and V86-mode DOS programs | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-2 | MUST | verified |  | Intercept DMA-port accesses made by **32-bit DOS-extender programs** (tested: DOS/4GW, PMODE/W, DOS/32A) | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-3 | MUST | verified |  | Therefore, after the TSR has loaded, no protected-mode DOS program may be able to run with unrestricted port access | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-4 | MUST | verified |  | Extenders that look for a DPMI host through INT 2Fh AX=1687h must end up running trapped (`TRAP-2`) | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-5 | MUST | verified |  | Work alongside the memory manager that provides V86 mode and leave it working | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-6 | MUST | inferred |  | In a design that shares the fault path with a memory manager, take faults before the manager does and hand on every fault the TSR does not o... | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-7 | MUST | verified |  | In a design that uses the memory manager's I/O permission bitmap, leave the manager's A20 handling, PIC base addresses and existing port tra... | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-8 | SHOULD | inferred |  | In a design that edits the manager's I/O permission bitmap, remember which bits the manager had set before the TSR changed them, so that rem... | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-9 | SHOULD | verified |  | Work when QPIEMU (Jemm's port-trap interface) is loaded **before** the TSR | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-10 | MUST | verified |  | Keep all other I/O at full speed: ports outside those the design needs (`EMU-1`, `EMU-15`) must not fault | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-11 | MUST | inferred |  | Resume the interrupted program with its interrupt-flag and other state as it was at the fault, through the memory manager's normal return pa... | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| TRAP-12 | SHOULD | untested |  | Validate under EMM386 and QEMM | [dsdma/03-trap-mechanism.md](dsdma/03-trap-mechanism.md) |
| DPMI-1 | MUST | verified |  | Answer INT 2Fh AX=1687h as a DPMI host: AX=0; BX bit 0 set (32-bit programs supported); CL = processor type; DX = `005Ah` (version 0.90); SI... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-2 | MUST | verified |  | Answer INT 67h AX=DE00h with AH=84h so that no later program sees VCPI (`TRAP-3`) | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-3 | MUST | verified |  | Ignore INT 31h calls made from V86 mode (return without effect) | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-4 | MUST | verified |  | Run each client at ring 3 with its own descriptor table, with the I/O privilege level below the client's privilege level, so that its port I... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-5 | SHOULD | verified |  | Support nesting: a DPMI client that executes another DPMI program (for example a game launching its setup program) should work | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-6 | MUST | verified |  | Implement every function marked **Used** | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-7 | MAY | inferred |  | Also implement the functions marked **Implemented**: DOS-memory functions (0100-0102), resize (0503), physical mapping (0800) and virtual in... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-8 | MUST | verified |  | For a function the host does not support, return with carry set and an error code | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-9 | MAY | verified |  | Make the lock/unlock (0600-0603) and demand-paging hint (0702/0703) functions no-ops that report success | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-10 | MAY | untested |  | Provide DPMI 1.0 functions (0401, 0506/0507 and others) if a target game's extender needs them; Causeway-based programs are suspected to | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-11 | MUST | verified |  | Allocate extended memory for 0501 from the memory manager's pages (through VCPI in the original) and return it to the manager on 0502 | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-12 | MAY | verified |  | Commit pages lazily: the original reserves the address range at allocation and takes a page from the manager on the first touch, through a p... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-13 | MUST | verified |  | Report allocation failures with the DPMI error codes (8012h linear memory unavailable, 8013h physical memory unavailable, 8023h invalid hand... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-14 | MUST | verified |  | Allocate selectors as ring-3 data descriptors, with the 32-bit default flag set when the client is a 32-bit program | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-15 | MUST | inferred |  | Reflect hardware interrupts into the client's protected-mode handler (set with 0205), and software interrupts raised by a protected-mode cli... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| DPMI-16 | MUST | inferred |  | In a design that runs clients at ring 3 (`DPMI-4`), emulate `CLI`, `STI` and moves to and from control and debug registers, since these inst... | [dsdma/04-dpmi-host.md](dsdma/04-dpmi-host.md) |
| LIFE-1 | MUST | verified |  | Work when started with no arguments, taking its settings from the defaults in `LIFE-3` | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-2 | MUST | verified |  | Do not reset or power-cycle the card, and do not reprogram what the setup tool configured (clocks, interrupt routing and every legacy-block ... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-3 | MUST | verified |  | Unless another source of settings is provided (`DEC-2`), use these defaults, which are the original's compiled-in values: Sound Blaster base... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-4 | MAY | untested |  | Accept command-line overrides for the Sound Blaster base (220h, 240h, 260h, 280h), the DMA channel and the slave base | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-5 | MAY | untested |  | Instead of fixed defaults, read what the setup tool already programmed into the card's configuration (the Sound Blaster base and DMA channel... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-6 | MUST | verified |  | Not modify the interrupt routing the setup tool chose (INTA# mode, level-triggered setting in the PC's edge/level control registers, the car... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-7 | MUST | inferred |  | The card configuration (`HW-5` to `HW-7`, and the read of `HW-8` if made) must be complete before the first trapped access can reach the sla... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-8 | MUST | verified |  | On success, stay resident with exit code 0 (observed in an emulator run with the original) and leave the DOS environment alone | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-9 | MUST | inferred |  | On failure (no PCI BIOS, no card, no VCPI, unsupported memory manager), print a clear message and exit with a nonzero code, leaving no half-... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-10 | SHOULD | untested |  | Run every check that can fail (PCI BIOS, card search, VCPI and memory-manager support) before the first write to the card, so that a failure... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-11 | SHOULD | untested |  | Detect a second copy of itself already resident and refuse to install again | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-12 | MAY | untested |  | Write the slave's **Master Clear** at install, and/or when the guest writes the 8237 master-clear port | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-13 | MAY | untested |  | A status command that reports whether the TSR is resident, the hooked channel, the slave base and the number of trapped accesses handled | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-14 | MAY | untested |  | An unload command that restores the memory manager's tables and releases the memory (`TRAP-8`) | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-15 | MAY | untested |  | A diagnostic mode that logs trapped accesses (port, value, direction) to the console or a file | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| LIFE-16 | MAY | inferred |  | Document that on a chipset the setup tool does not recognise, its own DMA self-test is expected to fail, because the card is not in D-DMA mo... | [dsdma/05-lifecycle.md](dsdma/05-lifecycle.md) |
| TEST-1 | MUST | verified |  | **Installation.** Under Jemm with the stub PCI BIOS above, the TSR installs and returns 0 | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-2 | MUST | verified |  | **Pass-through.** Run a real-mode program that reads, before the TSR is loaded and again after, the address and count ports of channels 0, 2... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-3 | MUST | verified |  | **Hooked channel.** On the unbacked slave, a real-mode (V86) program that clears the flip-flop (`OUT 0Ch`) and reads port 02 twice reads FFF... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-4 | MUST | verified |  | **Trap path.** Under a debugger that can single-step, a V86 `IN AL,02` executed after load passes through the TSR's fault handler and the ne... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-5 | MUST | verified |  | **VCPI is hidden** (for a design that hides VCPI, `TRAP-3`, `DPMI-2`) | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-6 | MUST | verified |  | **Extenders run.** Build one test program for each of DOS/4GW, PMODE/W and DOS/32A that executes: `OUT 0Ch,0`; `OUT 02h,12h`; `OUT 02h,34h`;... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-7 | MUST | verified |  | **API subset** (for a design that provides its own DPMI host, chapter 4) | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-8 | SHOULD | verified |  | **Jemm trap order.** Loaded after QPIEMU, the TSR works and the extenders of `TEST-6` run | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-9 | MUST | untested |  | **Real games on real hardware.** Doom and Duke Nukem 3D (DOS/4GW and its relatives, and Watcom-based extenders) start, reach their menu or d... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-10 | SHOULD | untested |  | **The warm-up symptom.** The reference machine is the one on which the original showed an unreliable first DMA after load: a Supermicro X10S... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-11 | SHOULD | untested |  | **Other memory managers.** Repeat `TEST-1` to `TEST-7` under EMM386 and QEMM (`TRAP-12`) | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-12 | SHOULD | untested |  | **Other extenders.** Run a program built with Causeway and with an extender that wants DPMI 1.0 (`DPMI-10`) | [dsdma/06-validation.md](dsdma/06-validation.md) |
| TEST-13 | SHOULD | untested |  | **Quake.** The original's run of Quake crashed with an invalid-opcode fault under Jemm both before and after any change, apparently unrelate... | [dsdma/06-validation.md](dsdma/06-validation.md) |
| SDS-1 | SHOULD | verified |  | Perform the steps of sections 1.2 to 1.7 and chapter 2 in this order: card search; BAR0 assignment; interrupt routing; power-up; native engi... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-2 | MUST | verified |  | Find the card through the PCI BIOS (INT 1Ah, AX=B102h) by vendor and device ID | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-3 | MUST | verified |  | If BAR0 (offset 10h) is zero, assign it: save the command register (offset 04h), clear its low three bits (I/O space, memory space, bus mast... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-4 | MUST | verified |  | Set the command register's memory-space and bus-master bits (04h /= 06h), remembering the value it held when this step runs (the value left ... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-5 | MUST | verified |  | Route the card's INTA# line to the PCI interrupt number given by the settings (the interaction specification's key table names it; stock: 5)... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-6 | MUST | verified |  | Make that interrupt level-triggered in the PC's edge/level control registers (ports 4D0h and 4D1h) by read-modify-write of the bit for the i... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-7 | MAY | inferred |  | Scan for free interrupts | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-8 | MUST | verified | DS-Y | Read the Power Control register (offset 4Ah) | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-9 | MUST | verified |  | Do not write offset 4Eh on a YMF724F | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-10 | MUST | verified |  | Through BAR0, write: +84h = 0 (native DAC output volume); +108h = 0001_0000h and then 0 (a pulse of the native engine's reset bit); +150h, +... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-11 | MUST | verified | DS-Y | Read the DS-1 Control register (offset 48h) | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-12 | MUST | verified |  | Wait for the codec: poll BAR0+66h bit 15 (primary codec busy) until clear, at most 700,000 reads; then read AC'97 register 26h (power-down c... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-13 | MAY | verified |  | Copy the vendor's microcode into the card's instruction RAM through BAR0: two images (DSP and controller) for every device value except one ... | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-14 | MAY | verified |  | Start the native engine (BAR0+114h = 1) after the microcode download | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-15 | MUST | verified |  | Leave the native engine stopped (BAR0+114h = 0) when the tool exits (`SDS-28`) | [setupds/01-bring-up.md](setupds/01-bring-up.md) |
| SDS-16 | MUST | verified | DS-Y | **Low word = 3F4Fh.** The four enables (SBEN, FMEN, MPU, joystick) give 000Fh; the Sound Blaster DMA field set to channel 1 gives 0040h; and... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-17 | MUST | verified | DS-Y | **High word = 9800h.** The DMA mode field (SMOD, bits 12:11 of offset 42h) is 11b, a value the datasheet marks reserved, and the interrupt m... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-18 | SHOULD | inferred |  | On an unrecognised chipset, fill both interrupt fields with 7 for every interrupt mode (legacy, INTA# or serialised, as set by the interrupt... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-19 | MUST | verified |  | On an **unrecognised chipset**, set SMOD to 3 and **do not write the D-DMA Slave Configuration register (offset 4Ch)**, leaving distributed ... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-20 | MUST | verified |  | Write the dword after the native engine quiesce and the codec wait, and before the mixers and the self-test | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-21 | MUST | verified |  | **Sound Blaster mixer**, only when the Sound Blaster base selector is below 4: through the Sound Blaster mixer index and data ports (base+4 ... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-22 | SHOULD | inferred |  | The three Sound Blaster mixer bytes correspond to the settings for legacy master, voice and FM volume, in that order | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-23 | MUST | verified |  | **AC'97 mixer**, through the codec: write registers 02h, 06h, 0Ah, 0Ch, 0Eh, 10h, 12h, 14h, 16h and 18h (master, mono, PC beep, phone, micro... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-24 | MUST | verified |  | **Codec access.** A write puts the word `register OR (codec number << 8)` at BAR0+62h and the data at BAR0+60h, then polls BAR0+66h bit 15 (... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-25 | SHOULD | verified |  | After the mixers, test four things and report them as four result bits: bit 0, the Sound Blaster DSP does not reset (not found); bit 1, an i... | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-26 | MUST | verified |  | Do not let a failure of the DMA test (bit 2) change the exit code (`INT-7`) | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-27 | MAY | verified |  | Before tear-down, read offset 40h back and print what is enabled | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| SDS-28 | MUST | verified |  | Tear-down: stop the native engine (BAR0+114h = 0), unmap BAR0, and restore the command register (offset 04h) to the value saved by `SDS-4` | [setupds/02-legacy-config.md](setupds/02-legacy-config.md) |
| STEST-1 | SHOULD | verified |  | **Starting state.** After a cold boot and before the tool has run: command register (04h) = 0006h; offset 40h (dword) = 0000_907Fh; DS-1 Con... | [setupds/03-validation.md](setupds/03-validation.md) |
| STEST-2 | SHOULD | verified |  | **End state of the silent apply with stock settings.** Offset 40h (dword) = 9800_3F4Fh; 48h = 0000h; 4Ah and 4Ch unchanged (0000h); the edge... | [setupds/03-validation.md](setupds/03-validation.md) |
| STEST-3 | SHOULD | verified |  | **Exit code.** The tool exits 2 (`interaction/`), and the vendor's boot batch file therefore loads the DMA master program | [setupds/03-validation.md](setupds/03-validation.md) |
| STEST-4 | SHOULD | untested |  | **Repeat run.** Running the tool a second time without a power cycle leaves the same end state | [setupds/03-validation.md](setupds/03-validation.md) |
| STEST-5 | SHOULD | untested |  | **Failure paths.** With no card present, or with a codec that never becomes ready, the tool prints a message and exits nonzero without chang... | [setupds/03-validation.md](setupds/03-validation.md) |
| INT-1 | MUST | verified |  | Respect the ownership table | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-2 | MUST | verified |  | Leave the card in the state above after a silent apply with stock settings, as far as the unrecognised-chipset path is concerned | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-3 | MUST | verified |  | Do not enable distributed DMA in the setup tool on an unrecognised chipset: SMOD must be left at 3 and offset 4Ch at its previous value | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-4 | MUST | verified |  | The TSR may assume, without checking, that the interrupt routing, IMOD, the codec and the native engine are as left by the setup tool | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-5 | MAY | inferred |  | A TSR may leave the card's mixers and the interrupt configuration alone | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-6 | MUST | verified |  | The boot batch file runs the setup tool with its silent-apply switch and then branches on the exit code: 2 means "load the TSR"; anything el... | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-7 | MUST | verified |  | The exit code is: **1** if the Sound Blaster DSP was not found or the interrupt test failed (self-test result bits 0 or 1); otherwise **2** ... | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-8 | MUST | untested |  | A failure of the setup tool before the self-test (no card found, codec never ready, BAR0 cannot be assigned) must exit with a nonzero code o... | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-9 | MUST | verified |  | `FORCETSR` is true when the settings file sets it, or when the chipset is unrecognised and `LOADTSR` is nonzero (stock: 1) | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-10 | SHOULD | inferred |  | On a recognised chipset the exit code is expected to be 0 and no TSR is loaded | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-11 | MUST | verified |  | The setup tool reads the settings file; the TSR does not | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-12 | MAY | inferred |  | Because of `INT-11`, a Sound Blaster base other than 220h chosen in the setup tool is overwritten, since the TSR writes the base field and t... | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-13 | MAY | untested |  | Carry the user's choices to the TSR (a command line, reading the card, or sharing the file) | [interaction/01-handover.md](interaction/01-handover.md) |
| INT-14 | MUST | verified |  | The file is ASCII text, one setting per line, written `KEY=VALUE` with no spaces in the stock file, and lines end in carriage return and lin... | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| INT-15 | MUST | verified |  | A key that is absent from the file reads as 0 | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| INT-16 | SHOULD | inferred |  | Keys are matched by name, not by their position in the file | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| INT-17 | SHOULD | inferred |  | The mixer values are hexadecimal: the stock value 77 for the legacy mixer keys becomes the data byte FFh only if it is read as 77h | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| INT-18 | MAY | inferred |  | The interactive mode of the setup tool writes this file, and the silent apply reads it back ("apply the saved settings") | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| INT-19 | MAY | untested |  | A replacement setup tool may define a different settings format, or read this one | [interaction/02-settings-file.md](interaction/02-settings-file.md) |
| ITEST-1 | SHOULD | verified |  | **Hand-over state.** After the setup tool's silent apply with stock settings, the registers of the table in 1.2 hold the listed values | [interaction/03-validation.md](interaction/03-validation.md) |
| ITEST-2 | SHOULD | verified |  | **Exit code.** With stock settings on that machine the silent apply exits with 2, and the boot batch file proceeds to the TSR branch | [interaction/03-validation.md](interaction/03-validation.md) |
| ITEST-3 | MUST | inferred |  | **TSR after setup.** After the TSR loads, the high word of the dword at offset 40h is 9000h (SMOD = 10b, IMOD = 1 preserved) and offset 4Ch ... | [interaction/03-validation.md](interaction/03-validation.md) |
| ITEST-4 | SHOULD | untested |  | **Mixing and matching.** A replacement setup tool run with the vendor's TSR, and the vendor's setup tool run with a replacement TSR, both pa... | [interaction/03-validation.md](interaction/03-validation.md) |
| ITEST-5 | SHOULD | untested |  | **Non-default settings.** A selection other than the stock Sound Blaster base, interrupt or DMA channel is carried through to the TSR (`IDEC... | [interaction/03-validation.md](interaction/03-validation.md) |
