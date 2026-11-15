# 2. DMA emulation (`EMU-`)

What the TSR does when a program accesses the 8237 ports. "Trapped" means the access reaches the TSR's handler; how the trap is
arranged is in [`03-trap-mechanism.md`](03-trap-mechanism.md).

## 2.1 Which accesses are emulated

- **EMU-1** `MUST` `verified` - Handle accesses to these ports: DMA1 00-0F, DMA2 C0-C7 and D0-DE (even ports), and the page registers 81, 82, 83, 87, 89, 8A, 8B. Do not take over port 80 (the POST and delay port) or the other page-range ports 84-86, 88, 8C-8F, which software uses for timing. Ports C8-CF (channels 6 and 7) were not seen trapped in the original's run; see section 7.2. A design may handle fewer ports than this if the result seen by the guest is the same (`EMU-15`).
- **EMU-2** `MUST` `verified` - Redirect the **hooked channel** (`EMU-4`, `DEC-5`) to the slave. For every other channel, an access must give the guest exactly the result it would give if the TSR were not loaded. Observed in an emulator run: after loading, channel 0, 2 and 3 address and count, the page registers for those channels, and channel 5 reads were identical to the pre-load baseline. How that result is produced is not specified. The original appears to perform those accesses itself without involving the memory manager (`inferred`).
- **EMU-3** `MUST` `inferred` - Resolve which channel an access belongs to from the port (and, for the mask and mode ports, from the channel bits in the written byte), so that a single write to a shared port such as the mode port is split correctly between the hooked channel and the others.
- **EMU-4** `SHOULD` `untested` - Let the hooked channel be chosen on the command line (`LIFE-3`), not only fixed at 1. The original has a hooked-channel setting but runs with 1 and no command line.

## 2.2 Instruction forms

- **EMU-5** `MUST` `verified` - Handle every I/O instruction form a program can use on these ports: `IN`/`OUT` with immediate and `DX` port, byte, word and doubleword sizes, and `INSB/W/D` and `OUTSB/W/D` with and without `REP`, including the operand-size (66h) and address-size (67h) prefixes and segment overrides. The original's instruction decoder covers all of these (read in its code). The runs exercised only byte-wide `IN`/`OUT` and a `REP OUTSB` followed by `REP INSB` on the hooked channel, which went through the trap without a crash.
- **EMU-6** `MUST` `inferred` - Treat a word or doubleword access to an 8-bit port as the equivalent run of byte accesses to consecutive ports. (The original's splitting loop was only partly read; low to high byte order is the architectural rule.)
- **EMU-7** `MUST` `inferred` - After handling an access, resume the program at the next instruction (past prefixes), with registers and flags as the real instruction would have left them, including `SI`/`DI`/`CX` advance for string forms.
- **EMU-8** `MUST` `inferred` - If the faulting instruction is not one the TSR handles, or the port is not one it owns, do not consume the fault: pass it on to whatever handled it before (the memory manager's own handler), so unrelated faults and the manager's own traps keep working. In the original the handler returns "not handled" in this case and the previous handler runs (read in its code, not exercised).

## 2.3 Register behaviour on the hooked channel

"Slave" below means the register at the offset in the table in [`01-card-interface.md`](01-card-interface.md#13-slave-register-layout).

| Guest access | Required effect | Tag |
|---|---|---|
| Write address (00/02/04/06, two writes) | Track the byte-pointer flip-flop; write low then high byte to slave +0, +1 | verified |
| Read address | Read slave +1, +0 and return the byte the flip-flop selects | verified |
| Write count (01/03/05/07, two writes) | As address, to slave +4, +5 | verified |
| Read count | Tear-safe read of slave +5, +4 (`HW-12`), returned a byte at a time | verified |
| Write page (83 for channel 1) | Store and write to slave +2 | verified |
| Read page | Read slave +2 | verified |
| Write mode (0B) with channel bits = hooked channel | Write to slave +Bh | verified |
| Read status (08) | Merge the slave's status with the real controller's (see `EMU-11`) | verified |
| Single-channel mask (0A), clear mask (0E), write-all-masks (0F) | Translate to a write of slave +Fh (see `EMU-12`) | inferred |
| Write command (08) | Not forwarded to the slave by the original | inferred |
| Write request (09) | Not forwarded to the slave by the original | verified |
| Master clear (0D) | Resets only the TSR's own software state in the original; no slave write | verified |
| Clear flip-flop (0C) | Reset the TSR's flip-flop view for the controller | inferred |

- **EMU-9** `MUST` `inferred` - Keep the 8237 byte-pointer flip-flop of each controller (DMA1, DMA2) consistent between the TSR and the real controller. The flip-flop is shared by all four channels of a controller, so a program may interleave address writes to the hooked channel with address writes to others; neither must see the other's byte go to the wrong half. (Shared flip-flops are verified in the original; interleaved programming was not exercised.)
- **EMU-10** `MUST` `verified` - For the 8-bit hooked channel, compose the transfer address as the page register in bits 23:16 with the 16-bit address below it. The treatment of 16-bit channels (5-7) was not established; see section 7.2.
- **EMU-11** `MUST` `verified` `DS-I` - **Status read**: return the real controller's status for the channels it still owns, with the hooked channel's terminal-count and request bits taken from the slave. Observed in an emulator run with an unbacked slave (reads FFh): before load status read 00h, after load 22h, which is the hooked channel's two bits (bit 1 and bit 5) forced high and everything else unchanged.
- **EMU-12** `MUST` `inferred` `DS-I` - **Mask writes**: the slave has only a Write-All-Masks register. A single-channel mask or clear-mask write for the hooked channel must be rewritten into the Write-All-Masks layout (DS-I describes the fold); a write for another channel must go to the real controller untouched. The original performs a shift and mask on the byte before writing slave +Fh; its exact bit layout was inferred from the datasheet, not independently verified.
- **EMU-13** `MUST` `verified` - Preserve the guest's view of unrelated state: in the emulator run the temporary register and mask-all readbacks were identical before and after load.

## 2.4 Behaviour a conforming TSR must **not** have

- **EMU-14** `MUST` `verified` - Not touch A20 or the keyboard controller, not remap the interrupt controllers, and not claim the PIC ports as its own. The original does none of these; A20 and PIC bases belong to the memory manager. (The original registers the PIC ports only to observe mask and EOI traffic and passes every access to the hardware; the reason is not established and no requirement depends on it.)
- **EMU-15** `MAY` `untested` - Avoid taking a fault for ports of unhooked channels where the memory manager does not itself need them. The original pays a fault for every access to the trapped ports even for unhooked channels; whether untrapping them is safe was not tested. The flip-flop shared by all four channels of a controller (`EMU-9`) is the likely reason the unhooked address and count ports are trapped, so a design that leaves them untrapped must still keep the flip-flop consistent.
