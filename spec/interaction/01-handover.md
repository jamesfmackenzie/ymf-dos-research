# 1. Ownership, hand-over state and boot flow (`INT-`)

## 1.1 Who owns what

| Part of the card or machine | Owner |
|---|---|
| Register window assignment, power-up, AC-link reset, codec ready, native engine quiesce | Setup tool |
| Interrupt routing (PCI INTA# to an interrupt number, the edge/level setting, the card's interrupt line) and the interrupt mode (IMOD) | Setup tool |
| Legacy FM, MPU-401 and joystick enables, and the Sound Blaster and MPU-401 interrupt fields | Setup tool |
| The Sound Blaster enable, base and DMA channel fields | Shared: the setup tool writes the initial values, the TSR rewrites them from its own defaults (`INT-10`) |
| Mixer settings (Sound Blaster and AC'97) | Setup tool |
| The DMA mode field (SMOD) and the D-DMA slave base and enable | TSR |
| The PC's DMA port accesses | TSR |

- **INT-1** `MUST` `verified` - Respect the ownership table: on an unrecognised chipset the setup tool programs everything in its rows and leaves distributed DMA to the TSR; the TSR changes only the fields in its rows (and in addition may rewrite the shared Sound Blaster enable, base and DMA channel fields) and does not reset the card or touch the interrupt configuration.

## 1.2 State at the hand-over

On the reference machine (a Supermicro X10SAE with a YMF724F, cold boot, stock settings) the setup tool leaves the following. Offsets are PCI configuration offsets unless marked BAR0 (the card's memory-mapped register window).

| Item | Value after the setup tool | Notes |
|---|---|---|
| 40h (dword) | 9800_3F4Fh | Legacy and Extended Legacy Audio Control: Sound Blaster, FM, MPU-401 and joystick enabled; DMA channel 1; both interrupt fields 7 (reserved); SMOD = 3 (reserved); IMOD = 1 (INTA#) |
| 3Ch | 05h | Interrupt line |
| 4D0h/4D1h (edge/level) | 20h | Interrupt 5 level-triggered |
| 48h | 0000h | AC-link and local reset released |
| 4Ah | 0000h | No power-down bits set |
| 4Ch | 0000h | D-DMA slave disabled |
| 04h | unchanged (0006h) | Memory space and bus master on, as the BIOS left them |
| BAR0+108h, +114h | 0 | Native engine quiet and stopped |
| AC'97 register 26h | 000Fh | Codec ready |

- **INT-2** `MUST` `verified` - Leave the card in the state above after a silent apply with stock settings, as far as the unrecognised-chipset path is concerned. In particular: SMOD = 3 and the slave disabled (the TSR enables it), IMOD = 1, the interrupt routed and level-triggered, and the codec ready.
- **INT-3** `MUST` `verified` - Do not enable distributed DMA in the setup tool on an unrecognised chipset: SMOD must be left at 3 and offset 4Ch at its previous value.
- **INT-4** `MUST` `verified` - The TSR may assume, without checking, that the interrupt routing, IMOD, the codec and the native engine are as left by the setup tool. It may read the card's Interrupt Line (3Ch) to learn the interrupt number; it does not change the routing.
- **INT-5** `MAY` `inferred` - A TSR may leave the card's mixers and the interrupt configuration alone. The original does not touch either.

## 1.3 Boot flow and exit codes

- **INT-6** `MUST` `verified` - The boot batch file runs the setup tool with its silent-apply switch and then branches on the exit code: 2 means "load the TSR"; anything else does not. The vendor's batch file sets the Sound Blaster environment variable (`BLASTER`) only in the branch that does **not** load the TSR; a TSR cannot set its parent's environment, so a user of the TSR branch has to set it.
- **INT-7** `MUST` `verified` - Exit code **1**: the Sound Blaster DSP was not found or the interrupt test failed (self-test result bits 0 or 1). Exit code **2**: the self-test did not fail on those bits, legacy audio is enabled in the settings, and the TSR is wanted (the "force TSR" condition below). Exit code **0**: otherwise. Exit code 1 takes precedence over 2. A failure of the DMA check (bit 2) or of the FM check (bit 3) alone does not change the exit code. With `LOADTSR` 0 and `FORCETSR` 0 the exit code is 0. The codes for other failures (no card, codec timeout) were not established.
- **INT-8** `MUST` `verified` - The TSR is wanted when the chipset is unrecognised and the settings request it (stock: yes). The original sets an internal "force TSR" flag in that case; the flag can also be set in the settings file.
- **INT-9** `SHOULD` `inferred` - On a recognised chipset the exit code is expected to be 0 and no TSR is loaded. This path has not been run on hardware.

## 1.4 The settings hand-over

- **INT-10** `MUST` `verified` - The setup tool reads the settings file; the TSR does not. The TSR uses compiled-in defaults: Sound Blaster base 220h, DMA channel 1, slave base F390h, and the interrupt it reads from the card.
- **INT-11** `MAY` `inferred` - Because of `INT-10`, a user who chooses a non-default Sound Blaster base, interrupt or DMA channel in the setup tool gets the defaults written back by the TSR: the choice is lost. The stock settings coincide with the TSR's defaults, so default setups are unaffected. Not tested on hardware.
- **INT-12** `MAY` `untested` - Carry the user's choices to the TSR (a command line, reading the card, or sharing the file). This is a decision (`IDEC-1`).
