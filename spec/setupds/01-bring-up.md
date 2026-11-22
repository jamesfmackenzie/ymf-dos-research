# 1. Bring-up sequence (`SDS-`)

What the silent apply does to the card, in order. Register names are from the YMF724F datasheet (DS-Y) and the Linux `ymfpci` driver. Values are for the stock settings and a cold-booted card; the datasheet's power-on defaults are given where they decide whether a step does anything.

## 1.1 Order

- **SDS-1** `SHOULD` `verified` - Perform the steps of sections 1.2 to 1.7 and chapter 2 in this order: card search; BAR0 assignment; interrupt routing; power-up; native engine quiesce; AC-link reset and codec wait; (optional) microcode download; start of the native engine; legacy configuration (chapter 2); mixers; self-test; status report; tear-down. This is the order the original uses. Which steps depend on an earlier one was not established, so a replacement may reorder only what it can show to be independent. Two orderings are firm (`MUST`): the legacy dword is written after the codec wait and before the mixers and the self-test (`SDS-20`), and the tear-down comes last (`SDS-28`).

## 1.2 Finding the card and its register window

- **SDS-2** `MUST` `verified` - Find the card through the PCI BIOS (INT 1Ah, AX=B102h) by vendor and device ID. Only device ID 000Dh has been run.
- **SDS-3** `MUST` `verified` - If BAR0 (offset 10h) is zero, assign it: save the command register (offset 04h), clear its low three bits (I/O space, memory space, bus master), size the BAR with an all-ones write and read-back, write a base address, and restore the command register. If BAR0 is already assigned, leave it alone. On the reference machine it was already assigned, so this path was not exercised on hardware.
- **SDS-4** `MUST` `verified` - Set the command register's memory-space and bus-master bits (04h |= 06h) for the duration of the setup, remembering the old value, and restore the old value at tear-down (`SDS-28`).

## 1.3 Interrupt routing

- **SDS-5** `MUST` `verified` - Route the card's INTA# line to the PCI interrupt number given by the settings (the interaction specification's key table names it; stock: 5) with the PCI BIOS call "set PCI hardware interrupt" (INT 1Ah, AX=B10Fh), and make the card's Interrupt Line register (offset 3Ch) read that number.
- **SDS-6** `MUST` `verified` - Make that interrupt level-triggered in the PC's edge/level control registers (ports 4D0h and 4D1h) by read-modify-write of the bit for the interrupt number, leaving the other bits as they were. On the reference machine the bit was already set by the BIOS, so the register was unchanged (20h before and after).
- **SDS-7** `MAY` `inferred` - Scan for free interrupts. The original does this before power-up; its purpose was not traced and nothing later was seen to depend on it.

## 1.4 Power-up

- **SDS-8** `MUST` `verified` `DS-Y` - Read the Power Control register (offset 4Ah). **Only if it is not zero**, clear its bits in stages with a delay between stages: bit 0 (DMC); then bits 2:0 (DPLL1, DPLL0); then bits 5:0 (PSN, PSL1, PSL0). Then, if bit 13 (PR5) is clear, clear bit 12 (PR4, the AC-link) together with bits 5:0, wait, and clear bits 15:8; if PR5 is set, set bit 2 of the DS-1 Control register (offset 48h), wait, then clear bits 15:8. Bits 7:6 are always preserved. The datasheet's power-on default is 0000h, so on a cold boot this step does nothing.
- **SDS-9** `MUST` `verified` - Do not write offset 4Eh on a YMF724F. The original writes 4Eh = 0 during power-up only on parts whose stored identification value (compared with 10h, 12h and 20h) matches, and the YMF724F (device 000Dh, revision 03h) matches none of them. The identification value is most likely the PCI device ID, which is inferred; that the YMF724F skips the branch is verified.

## 1.5 Native engine quiesce

- **SDS-10** `MUST` `verified` - Through BAR0, write: +84h = 0 (native DAC output volume); +108h = 0001_0000h and then 0 (a pulse of the native engine's reset bit); +150h, +154h, +158h, +15Ch and +160h = 0 (the record and effect map and control-base registers); +80h = 3FFF_3FFFh (legacy output volume, both channels at maximum). Register names are the Linux driver's; the values are the original's.

## 1.6 AC-link reset and codec ready

- **SDS-11** `MUST` `verified` `DS-Y` - Read the DS-1 Control register (offset 48h). **Only if bits 1:0 are not zero**, write the value with bits 1:0 set, then the value with bits 1:0 cleared (release of CRST# and XRST#). The datasheet's power-on default is 0001h, so on a cold boot this path is taken and the register reads 0000h afterwards.
- **SDS-12** `MUST` `verified` - Wait for the codec: poll BAR0+66h bit 15 (primary codec busy) until clear, at most 700,000 reads; then read AC'97 register 26h (power-down control/status) up to 20,000 times, with one I/O port read between reads, until (value AND 0Fh) = 0Fh. If either wait times out, the setup fails (see the exit code in the `interaction/` specification).

## 1.7 Microcode and native engine

- **SDS-13** `MAY` `verified` - Copy the vendor's microcode into the card's instruction RAM through BAR0: two images (DSP and controller) for every device value except one (12h), which gets one. The sizes match the Linux driver's DSP and controller lengths. The images are data inside the original program; **this specification does not supply them and does not say where a replacement gets them.** Whether legacy Sound Blaster operation needs them is not established here (section 4.2).
- **SDS-14** `MAY` `verified` - Start the native engine (BAR0+114h = 1) after the microcode download.
- **SDS-15** `MUST` `verified` - Leave the native engine stopped (BAR0+114h = 0) when the tool exits (`SDS-28`).
