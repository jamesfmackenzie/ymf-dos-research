# 3. Validation (`STEST-`)

How to tell whether a replacement of the card setup tool meets this specification. There is no emulator check, because no emulator models the card's registers, so everything here needs a real YMF724F on a machine with an unrecognised chipset, read with a PCI configuration and memory-space dump tool.

## 3.1 Reference machine

A Supermicro X10SAE (Intel C226) with a YMF724F, cold-booted. The values below were read on that machine only, so they are reference values, not conformance tests for every board.

## 3.2 Checks

- **STEST-1** `SHOULD` `verified` - **Starting state.** After a cold boot and before the tool has run: command register (04h) = 0006h; offset 40h (dword) = 0000_907Fh; DS-1 Control (48h) = 0001h; Power Control (4Ah) = 0000h; D-DMA Slave Configuration (4Ch) = 0000h; BAR0+80h = 3FFF_3FFFh; BAR0+84h, +108h and +114h = 0; edge/level register 4D0h = 20h (interrupt 5 level-triggered).
- **STEST-2** `SHOULD` `verified` - **End state of the silent apply with stock settings.** Offset 40h (dword) = 9800_3F4Fh; 48h = 0000h; 4Ah and 4Ch unchanged (0000h); the edge/level register still 20h; BAR0+108h and +114h = 0; the last codec command written was register 18h = 0808h; AC'97 register 26h reads 000Fh.
- **STEST-3** `SHOULD` `verified` - **Exit code.** The tool exits 2 (`interaction/`), and the vendor's boot batch file therefore loads the DMA master program.
- **STEST-4** `SHOULD` `untested` - **Repeat run.** Running the tool a second time without a power cycle leaves the same end state. The original was not run twice in the recorded session.
- **STEST-5** `SHOULD` `untested` - **Failure paths.** With no card present, or with a codec that never becomes ready, the tool prints a message and exits nonzero without changing the card's configuration beyond what it had already done. Neither case has been exercised.
