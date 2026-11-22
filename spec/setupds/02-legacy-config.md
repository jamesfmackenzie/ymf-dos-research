# 2. Legacy configuration, mixers, self-test, tear-down (`SDS-`)

## 2.1 The legacy audio dword (offset 40h)

The original builds one 32-bit value for PCI configuration offset 40h (the Legacy Audio Control register in the low word and the Extended Legacy Audio Control register in the high word, offset 42h) and writes it once. For the stock settings on a YMF724F behind an unrecognised chipset the result is `9800_3F4Fh`, read back on hardware.

- **SDS-16** `MUST` `verified` `DS-Y` - **Low word = 3F4Fh.** The four enables (SBEN, FMEN, MPU, joystick) give 000Fh; the Sound Blaster DMA field set to channel 1 gives 0040h; and the Sound Blaster and MPU interrupt fields both set to 7 (reserved) give 3F00h. MIEN (bit 4) is not set.
- **SDS-17** `MUST` `verified` `DS-Y` - **High word = 9800h.** The DMA mode field (SMOD, bits 12:11 of offset 42h) is 11b, a value the datasheet marks reserved, and the interrupt mode bit (IMOD, bit 15) is 1: the card signals its Sound Blaster interrupt on PCI INTA#.
- **SDS-18** `SHOULD` `inferred` - Fill both interrupt fields with 7 when the settings select INTA# interrupts, and otherwise write the Sound Blaster and MPU interrupt selections from the settings. The original has a branch that fills both fields with 7 when one settings byte equals 1; that the byte is the interrupt-mode setting is inferred, because the evidence for which key it is is not conclusive.
- **SDS-19** `MUST` `verified` - On an **unrecognised chipset**, set SMOD to 3 and **do not write the D-DMA Slave Configuration register (offset 4Ch)**, leaving distributed DMA off. This is what makes a second program necessary (see `interaction/`). On a recognised chipset the original programs the chipset instead; that is not covered.
- **SDS-20** `MUST` `verified` - Write the dword after the native engine quiesce and the codec wait, and before the mixers and the self-test.

## 2.2 Mixers

- **SDS-21** `MUST` `verified` - **Sound Blaster mixer**, only when the Sound Blaster base selector is below 4: through the Sound Blaster mixer index and data ports (base+4 and base+5) write register 22h, then 04h, then 26h. Each data byte is `(value * 2) OR 11h`, where `value` is the settings value masked with 77h. With the stock value 77h the byte written is FFh.
- **SDS-22** `SHOULD` `inferred` - The three Sound Blaster mixer bytes correspond to the settings for legacy master, voice and FM volume, in that order. They are consecutive and masked with the same value in the original's loader; the exact mapping was not confirmed.
- **SDS-23** `MUST` `verified` - **AC'97 mixer**, through the codec: write registers 02h, 06h, 0Ah, 0Ch, 0Eh, 10h, 12h, 14h, 16h and 18h (master, mono, PC beep, phone, microphone, line, CD, video, auxiliary, PCM) from the corresponding settings. The settings are masked as they are loaded: 9F1Fh for master, PCM, line, CD, video and auxiliary; 801Fh for mono, PC beep and phone; 805Fh for microphone. On the reference machine the last command written was register 18h = 0808h.
- **SDS-24** `MUST` `verified` - **Codec access.** A write puts the word `register OR (codec number << 8)` at BAR0+62h and the data at BAR0+60h, then polls BAR0+66h bit 15 (secondary codec: BAR0+6Ah) for at most 1,000 reads. A read puts `8000h OR register OR (codec << 8)` at BAR0+62h, polls the same bit, then reads the word at BAR0+64h (secondary: +68h) 600 times and keeps the last value.

## 2.3 Self-test

- **SDS-25** `SHOULD` `verified` - After the mixers, test four things and report them as four result bits: bit 0, the Sound Blaster DSP does not reset (not found); bit 1, an interrupt requested through the DSP does not arrive; bit 2, a DMA transfer through the PC's 8237 does not complete; bit 3, the FM synthesiser does not respond. The DMA test programs the 8237, issues a DSP DMA command and polls up to 2000h times for the interrupt flag.
- **SDS-26** `MUST` `verified` - Do not let a failure of the DMA test (bit 2) change the exit code (`INT-7`). On an unrecognised chipset the test is expected to fail: the original has the card in the reserved DMA mode with distributed DMA off while the test runs, so the test can only fail (inferred; the datasheet defines no behaviour for the reserved mode).

## 2.4 Report and tear-down

- **SDS-27** `MAY` `verified` - Before tear-down, read offset 40h back and print what is enabled. The message text is not specified.
- **SDS-28** `MUST` `verified` - Tear-down: stop the native engine (BAR0+114h = 0), unmap BAR0, and restore the command register (offset 04h) to the value saved by `SDS-4`. On the reference machine BAR0+108h and +114h read 0 afterwards.
