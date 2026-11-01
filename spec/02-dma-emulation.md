# 2. DMA emulation (`EMU-`)

What the TSR does when a program accesses the 8237 ports. "Trapped" means the access reaches the TSR's handler; how the trap is
arranged is in [`03-trap-mechanism.md`](03-trap-mechanism.md).

## 2.1 Which accesses are emulated

- **EMU-1** `MUST` `verified` `F15 E16` - Handle accesses to these ports: DMA1 00-0F, DMA2 C0-DE (even ports), and the page registers 81, 82, 83, 87, 89, 8A, 8B. Do not trap port 80 (the POST and delay port) or the other page-range ports 84-86, 88, 8C-8F, which software uses for timing.
- **EMU-2** `MUST` `verified` `F15 F16 E16` - Emulate exactly one channel, the **hooked channel**, which is the Sound Blaster DMA channel the card was configured for (`HW-5`, default 1). For every other channel, an access must behave exactly as if the TSR were not loaded. Observed in E16: after loading, channel 0, 2 and 3 address and count, the page registers for those channels, and channel 5 reads were identical to the pre-load baseline.
- **EMU-3** `MUST` `inferred` `F15` - Resolve which channel an access belongs to from the port (and, for the mask and mode ports, from the channel bits in the written byte), so that a single write to a shared port such as the mode port is split correctly between the hooked channel and the others.
- **EMU-4** `SHOULD` `untested` `F8` - Let the hooked channel be chosen on the command line (`LIFE-3`), not only fixed at 1. The original has a hooked-channel setting but runs with 1 and no command line.

## 2.2 Instruction forms

- **EMU-5** `MUST` `verified` `F15 E16` - Handle every I/O instruction form a program can use on these ports: `IN`/`OUT` with immediate and `DX` port, byte, word and doubleword sizes, and `INSB/W/D` and `OUTSB/W/D` with and without `REP`, including the operand-size (66h) and address-size (67h) prefixes and segment overrides. E16 steps a `REP OUTSB` followed by `REP INSB` on the hooked channel through the trap without a crash.
- **EMU-6** `MUST` `inferred` `F15` - Treat a word or doubleword access to an 8-bit port as the equivalent run of byte accesses to consecutive ports. (The original's splitting loop was only partly read; low to high byte order is the architectural rule.)
- **EMU-7** `MUST` `inferred` `F15` - After handling an access, resume the program at the next instruction (past prefixes), with registers and flags as the real instruction would have left them, including `SI`/`DI`/`CX` advance for string forms.
- **EMU-8** `MUST` `verified` `F15` - If the faulting instruction is not one the TSR handles, or the port is not one it owns, do not consume the fault: pass it on to whatever handled it before (the memory manager's own handler), so unrelated faults and the manager's own traps keep working.

## 2.3 Register behaviour on the hooked channel

"Slave" below means the register at the offset in the table in [`01-card-interface.md`](01-card-interface.md#13-slave-register-layout).

| Guest access | Required effect | Tag |
|---|---|---|
| Write address (00/02/04/06, two writes) | Track the byte-pointer flip-flop; write low then high byte to slave +0, +1 | verified (F15) |
| Read address | Read slave +1, +0 and return the byte the flip-flop selects | verified (F2 F4) |
| Write count (01/03/05/07, two writes) | As address, to slave +4, +5 | verified (F4 F15) |
| Read count | Tear-safe read of slave +5, +4 (`HW-12`), returned a byte at a time | verified (F2 F4) |
| Write page (83 for channel 1) | Store and write to slave +2 | verified (F15) |
| Read page | Read slave +2 | verified (F4) |
| Write mode (0B) with channel bits = hooked channel | Write to slave +Bh | verified (F4 F15) |
| Read status (08) | Merge the slave's status with the real controller's (see `EMU-11`) | verified (F2 E16) |
| Single-channel mask (0A), clear mask (0E), write-all-masks (0F) | Translate to a write of slave +Fh (see `EMU-12`) | inferred (F2) |
| Write command (08) | Not forwarded to the slave by the original | inferred (F4) |
| Write request (09) | Not forwarded to the slave by the original | verified (F1 F4) |
| Master clear (0D) | Resets only the TSR's own software state in the original; no slave write | verified (F15) |
| Clear flip-flop (0C) | Reset the TSR's flip-flop view for the controller | inferred (F15) |

- **EMU-9** `MUST` `inferred` `F15` - Keep the 8237 byte-pointer flip-flop of each controller (DMA1, DMA2) consistent between the TSR and the real controller. The flip-flop is shared by all four channels of a controller, so a program may interleave address writes to the hooked channel with address writes to others; neither must see the other's byte go to the wrong half. (Shared flip-flops are verified in the original; interleaved programming was not exercised.)
- **EMU-10** `MUST` `verified` `F15` - Compose the transfer address as page in bits 23:16 with the 16-bit address below it for 8-bit channels. For 16-bit channels (5-7) the address and count are in words, shifted left one bit; the exact rounding was not exhaustively read (`inferred`).
- **EMU-11** `MUST` `verified` `F2 E16 DS-I` - **Status read**: return the real controller's status for the channels it still owns, with the hooked channel's terminal-count and request bits taken from the slave. Observed in E16 with an unbacked slave (reads FFh): before load status read 00h, after load 22h, which is the hooked channel's two bits (bit 1 and bit 5) forced high and everything else unchanged.
- **EMU-12** `MUST` `inferred` `F2 DS-I` - **Mask writes**: the slave has only a Write-All-Masks register. A single-channel mask or clear-mask write for the hooked channel must be rewritten into the Write-All-Masks layout (DS-I describes the fold); a write for another channel must go to the real controller untouched. The original performs a shift and mask on the byte before writing slave +Fh; its exact bit layout was inferred from the datasheet, not independently verified.
- **EMU-13** `MUST` `verified` `E16` - Preserve the guest's view of unrelated state: in E16 the temporary register and mask-all readbacks were identical before and after load.

## 2.4 Behaviour a conforming TSR must **not** have

- **EMU-14** `MUST` `verified` `F15` - Not touch A20 or the keyboard controller, not remap the interrupt controllers, and not claim the PIC ports as its own. The original does none of these; A20 and PIC bases belong to the memory manager. (The original registers the PIC ports only to observe mask and EOI traffic and passes every access to the hardware; the reason is not established and no requirement depends on it.)
- **EMU-15** `SHOULD` `untested` `F15` - Avoid taking a fault for ports of unhooked channels where the memory manager does not itself need them. The original pays a fault for every access to the trapped ports even for unhooked channels; whether untrapping them is safe was not tested.
