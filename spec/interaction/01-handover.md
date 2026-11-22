# 1. Ownership, hand-over state and boot flow (`INT-`)

## 1.1 Who owns what

| Part of the card or machine | Owner |
|---|---|
| Register window assignment (BAR0), power-up, AC-link reset, codec ready, native engine quiesce | Setup tool |
| The PCI command register (04h): memory space and bus master | Setup tool; both must be left enabled at the hand-over. The TSR does not change it |
| Interrupt routing (PCI INTA# to an interrupt number, the edge/level setting, the card's interrupt line) and the interrupt mode (IMOD) | Setup tool |
| Legacy FM, MPU-401 and joystick enables, and the Sound Blaster and MPU-401 interrupt fields | Setup tool |
| The Sound Blaster enable, base and DMA channel fields | Shared: the setup tool writes the initial values, the TSR rewrites them from its own defaults (`INT-11`) |
| Mixer settings (Sound Blaster and AC'97) | Setup tool |
| The DMA mode field (SMOD) and the D-DMA slave base and enable | TSR |
| The PC's DMA port accesses | TSR |

- **INT-1** `MUST` `verified` - Respect the ownership table. In offsets 40h and 42h the TSR changes only SMOD, the Sound Blaster enable, base and DMA channel fields, and offset 4Ch; it changes no other bit, does not reset the card and does not touch the interrupt configuration. The setup tool leaves distributed DMA to the TSR.

## 1.2 State at the hand-over

On the reference machine (a Supermicro X10SAE with a YMF724F, cold boot, stock settings) the setup tool leaves the following. Offsets are PCI configuration offsets unless marked BAR0 (the card's memory-mapped register window) or given as I/O ports.

| Item | Value after the setup tool | Notes |
|---|---|---|
| 40h (dword) | 9800_3F4Fh | Legacy and Extended Legacy Audio Control: Sound Blaster, FM, MPU-401 and joystick enabled; DMA channel 1; both interrupt fields 7 (reserved); SMOD = 3 (reserved); IMOD = 1 (INTA#) |
| 3Ch | 05h | Interrupt line |
| Ports 4D0h/4D1h (edge/level) | 20h | Interrupt 5 level-triggered |
| 48h | 0000h | AC-link and local reset released |
| 4Ah | 0000h | No power-down bits set |
| 4Ch | 0000h | D-DMA slave disabled |
| 04h | unchanged (0006h) | Memory space and bus master on, as the BIOS left them; they must stay on |
| BAR0+108h, +114h | 0 | Native engine quiet and stopped |
| AC'97 register 26h | 000Fh | Codec ready |

- **INT-2** `MUST` `verified` - Leave the card in the state above after a silent apply with stock settings, as far as the unrecognised-chipset path is concerned. In particular: SMOD = 3 and the slave disabled (the TSR enables it), IMOD = 1, the interrupt routed and level-triggered, and the codec ready.
- **INT-3** `MUST` `verified` - Do not enable distributed DMA in the setup tool on an unrecognised chipset: SMOD must be left at 3 and offset 4Ch at its previous value.
- **INT-4** `MUST` `verified` - The TSR may assume, without checking, that the interrupt routing, IMOD, the codec and the native engine are as left by the setup tool. It may read the card's Interrupt Line (3Ch) to learn the interrupt number; it does not change the routing.
- **INT-5** `MAY` `inferred` - A TSR may leave the card's mixers and the interrupt configuration alone. The original does not touch either.

## 1.3 Boot flow and exit codes

- **INT-6** `MUST` `verified` - The boot batch file runs the setup tool with its silent-apply switch and then branches on the exit code: 2 means "load the TSR"; anything else does not. The vendor's batch file sets the Sound Blaster environment variable (`BLASTER`) only in the branch that does **not** load the TSR; a TSR cannot set its parent's environment, so a user of the TSR branch has to set it.
- **INT-7** `MUST` `verified` - The exit code is: **1** if the Sound Blaster DSP was not found or the interrupt test failed (self-test result bits 0 or 1); otherwise **2** if legacy audio is enabled in the settings (`LEGEN` nonzero) and the TSR is wanted (`FORCETSR` true); otherwise **0**. Code 1 takes precedence. A failure of the DMA check (bit 2) or of the FM check (bit 3) alone does not change the code.
- **INT-8** `MUST` `untested` - A failure of the setup tool before the self-test (no card found, codec never ready, BAR0 cannot be assigned) must exit with a nonzero code other than 2, so that the boot batch file does not load the TSR onto an unconfigured card. The original's codes for these failures were not established.
- **INT-9** `MUST` `verified` - `FORCETSR` is true when the settings file sets it, or when the chipset is unrecognised and `LOADTSR` is nonzero (stock: 1). With the stock settings on an unrecognised chipset the exit code is therefore 2. With `LOADTSR` 0 and `FORCETSR` unset the exit code is 0 whatever the chipset. `FORCETSR` set in the file on a recognised chipset is expected to give 2 as well (inferred from the code, not run).
- **INT-10** `SHOULD` `inferred` - On a recognised chipset the exit code is expected to be 0 and no TSR is loaded. This path has not been run on hardware.

## 1.4 The settings hand-over

- **INT-11** `MUST` `verified` - The setup tool reads the settings file; the TSR does not. The TSR uses compiled-in defaults for the Sound Blaster base (220h), the DMA channel (1) and the slave base (F390h). It may read the card's Interrupt Line (3Ch) to learn the interrupt number.
- **INT-12** `MAY` `inferred` - Because of `INT-11`, a Sound Blaster base other than 220h chosen in the setup tool is overwritten, since the TSR writes the base field and the slave configuration unconditionally. Whether a non-default DMA channel survives was not established: the original's write of the Legacy Audio Control register is conditional or absent. The stock settings coincide with the TSR's defaults, so default setups are unaffected. Not tested on hardware.
- **INT-13** `MAY` `untested` - Carry the user's choices to the TSR (a command line, reading the card, or sharing the file). This is a decision (`IDEC-1`).
