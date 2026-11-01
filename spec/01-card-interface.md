# 1. Card interface (`HW-`)

How the TSR finds the card, which PCI configuration registers it writes, and how the slave registers are laid out. Register
meanings are from the YMF724F datasheet (DS-Y); the sequence and values are what the original does and what the emulator
runs observed (E16).

## 1.1 Finding the card

- **HW-1** `MUST` `verified` `F5 F16` - Check for a PCI BIOS with INT 1Ah, AX=B101h (signature `PCI ` in EDX) and use the PCI BIOS read/write configuration functions (B108-B10Dh). The original does this itself and does not rely on `setupds` having done it.
- **HW-2** `MUST` `verified` `F6 F16` - Find the card with INT 1Ah, AX=B102h for vendor `1073h`, device `000Dh` (YMF724F). Only this ID has been exercised.
- **HW-3** `SHOULD` `untested` `F5` - Also accept other YMF7xx family devices (YMF724, 740, 744, 754) once their configuration registers have been checked against the datasheets. The original compares the device ID and revision with a small set of values it does not document; which IDs those are has not been established.
- **HW-4** `MUST` `inferred` `F5` - If there is no PCI BIOS or no matching card, do not install, print a message and return a nonzero exit code. The original has an error path that returns failure; its message and code were not captured.

## 1.2 PCI configuration the TSR writes

All three writes are read-modify-write: change only the named fields, preserve every other bit (in particular the interrupt mode set by `setupds`).

- **HW-5** `MUST` `verified` `F5 E16 DS-Y` - **Legacy Audio Control (offset 40h)**: make sure `SBEN` (bit 0) is set and the `SDMA` field (bits 7:6) holds the Sound Blaster DMA channel (default 1). The original reads the register first and tests bit 0; in E16 the stub's default is `907Fh` (SBEN set, channel 1) and the original writes nothing to offset 40h, so the write is evidently conditional (`inferred`). A replacement may write unconditionally or only when a change is needed.
- **HW-6** `MUST` `verified` `F5 F13 F16 DS-Y` - **Extended Legacy Audio Control (offset 42h, word)**: set `SMOD` (bits 12:11) to `10b`, which selects Distributed DMA, and set `SBIO` (bits 3:2) to the Sound Blaster base: 220h = 0, 240h = 4, 260h = 8, 280h = Ch. Starting from a freshly reset card with SBIO 220h the result is `1000h` (observed).
- **HW-7** `MUST` `verified` `F5 F16 DS-Y` - **D-DMA Slave Configuration (offset 4Ch, word)**: write the slave base with its low four bits cleared, then set bit 0 (`CE`, channel enable). With the default base `F390h` the register reads back `F391h` (observed). This is the write that turns D-DMA on.
- **HW-8** `MUST` `verified` `F5` - Read the Interrupt Line register (offset 3Ch, byte) after the writes above, to learn the card's interrupt without relying on a separate tool such as `YMFIRQ.exe`.
- **HW-9** `MUST` `verified` `F5` - Perform the configuration in the order 40h (if needed), 42h, 4Ch, then read 3Ch, before enabling any trap (see `LIFE-7`).
- **HW-10** `MUST` `inferred` `F13 F14` - Do not touch any other configuration register, in particular the interrupt mode (`IMOD`, 42h bit 15), the power and reset registers (48h, 4Ah, 4Eh) or the legacy I/O decodes, all of which `setupds` owns.

## 1.3 Slave register layout

The registers the original uses are all within 16 bytes of the slave base, for the one channel the card serves (inferred from
the datasheets and the access pattern; the datasheets' per-channel stride is not exercised). DS-I Table 25 gives the same layout
from the chipset side. Offsets are from the slave base.

| Offset | Register | 8237 port it replaces (DMA1) | Original forwards it? |
|---|---|---|---|
| +0 | Address, low byte | 00/02/04/06 (first write of the pair) | Yes |
| +1 | Address, high byte | same (second write of the pair) | Yes |
| +2 | Page | 87/83/81/82 | Yes |
| +4 | Word count, low byte | 01/03/05/07 | Yes |
| +5 | Word count, high byte | same | Yes |
| +8 | Command (write) / Status (read) | 08 | Status read only |
| +9 | Request (write) | 09 | **No, never written** |
| +Bh | Mode (write) | 0B | Yes |
| +Dh | Master Clear (write) | 0D | **No, never written** |
| +Fh | Write All Masks | 0A, 0E, 0F | Yes (see `EMU-12`) |

- **HW-11** `MUST` `verified` `F1 F2 F4 DS-I` - Use exactly these offsets for the registers in the "Yes" rows. They match the datasheet table offset for offset.
- **HW-12** `MUST` `verified` `F2 F4` - Read the 16-bit **current word count** so that a count changing between the two byte reads cannot produce a torn value: read high then low twice and keep the pair that did not roll over between reads. The original does this; a single naive read can return a torn value while the card is transferring.
- **HW-13** `MUST` `verified` `F4` - Write address and count low byte first, then high byte.
- **HW-14** `MAY` `untested` `F2 F6 DS-I` - Write **Master Clear (+Dh)** to the slave. The original never does, at install time or when the guest writes the 8237 master-clear port. Whether adding it fixes the unreliable first DMA after load is the open question (`DEC-1`).
- **HW-15** `MAY` `untested` `F2 DS-I` - Write **Request (+9)**. The original never does. A Sound Blaster does not use software DMA requests, so there is no known reason to.
