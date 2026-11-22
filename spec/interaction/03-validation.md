# 3. Validation (`ITEST-`)

All checks need a YMF724F on a machine with an unrecognised chipset (the reference machine: Supermicro X10SAE, cold boot). The values are those recorded in chapter 1.

- **ITEST-1** `MUST` `verified` - **Hand-over state.** After the setup tool's silent apply with stock settings, the registers of the table in 1.2 hold the listed values.
- **ITEST-2** `MUST` `verified` - **Exit code.** With stock settings on that machine the silent apply exits with 2, and the boot batch file proceeds to the TSR branch.
- **ITEST-3** `MUST` `verified` - **TSR after setup.** After the TSR loads, the high word of the dword at offset 40h is 9000h (SMOD = 10b, IMOD = 1 preserved) and offset 4Ch = F391h; offsets 3Ch, 48h and 4Ah are unchanged from the hand-over values.
- **ITEST-4** `SHOULD` `untested` - **Mixing and matching.** A replacement setup tool run with the vendor's TSR, and the vendor's setup tool run with a replacement TSR, both pass `ITEST-3` and give working Sound Blaster DMA in a game on the reference machine.
- **ITEST-5** `SHOULD` `untested` - **Non-default settings.** A selection other than the stock Sound Blaster base, interrupt or DMA channel is carried through to the TSR (`IDEC-1`) or, if not, the loss is documented (`INT-11`).
