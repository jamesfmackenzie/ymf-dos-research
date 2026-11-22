# 2. The settings file (`INT-`)

The setup tool takes its settings from a plain text file. A replacement setup tool that wants to honour existing files, and a tool that writes such files, need the grammar below. A replacement is free to define its own format instead (`IDEC-1`). The file's name and location are not part of this specification.

## 2.1 Grammar

- **INT-13** `MUST` `verified` - The file is ASCII text, one setting per line, written `KEY=VALUE` with no spaces in the stock file, and lines end in carriage return and line feed. The stock file is 353 bytes and not obfuscated.
- **INT-14** `MUST` `verified` - A key that is absent from the file reads as 0. The force-TSR key (below) is absent from the stock file and reads as 0.
- **INT-15** `MUST` `inferred` - Keys are matched by name, not by their position in the file. The setup tool looks the keys up in a fixed order, and the stock file lists them in a different order, so position does not appear to matter. Unrecognised keys and malformed lines were not tested.
- **INT-16** `MUST` `inferred` - The mixer values are hexadecimal: the stock value 77 for the legacy mixer keys becomes the data byte FFh only if it is read as 77h. The radix of the selector keys is not distinguishable in the stock file, where every selector is a single digit.

## 2.2 Keys

All keys were read from the original. "Stock" is the value in the vendor's default file. The meaning of each is verified unless marked.

| Key | Stock | Meaning |
|---|---|---|
| `LEGEN` | 1 | Legacy audio (Sound Blaster, FM, MPU-401, joystick) enabled |
| `SBIO` | 0 | Sound Blaster base selector, an index: 0 selects 220h; the others (240h, 260h, 280h) follow the datasheet's field encoding (inferred) |
| `SBIRQ` | 0 | Sound Blaster interrupt selector, an index: 0 selects interrupt 5 |
| `SBDMA` | 1 | Sound Blaster DMA channel selector, an index: 1 selects channel 1 |
| `FMIO` | absent | FM base selector (read, not in the stock file) |
| `MPUIO` | 0 | MPU-401 base selector: 0 selects 330h |
| `MPUIRQ` | 0 | MPU-401 interrupt selector |
| `JOYIO` | 0 | Joystick base selector |
| `INTAIRQ` | 5 | The interrupt number to route PCI INTA# to |
| `IRQMODE` | 1 | How the card signals interrupts: 0 legacy ISA lines, 1 PCI INTA#, 2 serialised IRQ. For 0 and 2 on an unrecognised chipset the interrupt fields are filled with 7 (reserved) |
| `DMAMODE` | 0 | 0 = PC/PCI DMA, 1 = distributed DMA. Acted on only for a recognised chipset |
| `LOADTSR` | 1 | Request the TSR when the chipset is unrecognised |
| `FORCETSR` | absent | Set by the tool when the chipset is unrecognised and `LOADTSR` is nonzero; may also be set in the file |
| `SLAVEBASE`, `SLAVEADDR` | 0, 0 | Feed a table of three distributed-DMA base addresses (base, +1000h, +2000h), the base masked with F000h and clamped to 1000h to D000h, default 8000h. Used only when programming a recognised chipset |
| `LEGMAS`, `VOICE`, `FM` | 77, 77, 77 | Legacy Sound Blaster mixer values, masked with 77h |
| `MASTER` | 0 | AC'97 master volume word, masked with 9F1Fh |
| `MONO`, `PCBEEP`, `PHONE` | 8000, 8000, 8008 | AC'97 words, masked with 801Fh |
| `MIC` | 8008 | AC'97 microphone word, masked with 805Fh |
| `LINE`, `CD`, `VIDEO`, `AUX` | 8808 each | AC'97 words, masked with 9F1Fh |
| `PCM` | 808 | AC'97 PCM word, masked with 9F1Fh |
| `SBFILE`, `NAFILE`, `FMFILE` | YMH8.WAV, YMH16.WAV, YMH.MID | File names for the interactive sound test (not on the silent path) |
| `FIRSTTRY`, `IRQSHARE`, `PIRQRC`, `DEBUG`, `REPEAT` | 1, 0, 0, absent, absent | Read by the tool. Their meaning was not established |

- **INT-17** `MAY` `inferred` - The interactive mode of the setup tool writes this file, and the silent apply reads it back ("apply the saved settings"). Not confirmed, because the interactive mode was not traced.
- **INT-18** `MAY` `untested` - A replacement setup tool may define a different settings format, or read this one. See `IDEC-1`.
