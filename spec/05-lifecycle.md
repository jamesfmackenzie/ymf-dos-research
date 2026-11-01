# 5. Installation and lifecycle (`LIFE-`)

How the TSR is started, what it assumes about `setupds`, its defaults, and the improvements an open replacement could add.

## 5.1 Where it fits at boot

On a machine with an unrecognised chipset, Yamaha's `LOADTSR.BAT` runs `setupds /s`, which programs the card and exits with
code 2, and then runs the TSR with **no command line** (F8, F13). The replacement is a drop-in for that last step.

- **LIFE-1** `MUST` `verified` `F8 F13` - Work when started with no arguments, taking its settings from the defaults in `LIFE-3`. The original's batch file never passes any.
- **LIFE-2** `MUST` `verified` `F13` - Assume `setupds /s` has already run: the legacy audio block has been configured, the card has been reset and clocked, and its interrupt has been routed. The TSR then only adds the D-DMA settings of chapter 1. It does not reset or power-cycle the card.
- **LIFE-3** `MUST` `verified` `F8 F13 E16` - Use these defaults, which are the original's compiled-in values: Sound Blaster base 220h, hooked DMA channel 1, slave base `F390h`; the interrupt is read from the card (`HW-8`), the original's default being IRQ 5. The original never reads `ds.ini`, so settings chosen in `setupds` for any of these are not carried over (F8, F13). That is a limitation of the original, not a requirement.
- **LIFE-4** `SHOULD` `untested` `F5 F8` - Accept command-line overrides for the Sound Blaster base (220h, 240h, 260h, 280h), the DMA channel and the slave base. The original reads its command line (F5) but nothing in its own batch file uses it, and the syntax was not recovered, so a replacement defines its own.
- **LIFE-5** `MAY` `untested` `F8 F13` - Instead of fixed defaults, read what `setupds` already programmed into the card's configuration (the Sound Blaster base and DMA channel in 40h and 42h) and keep it. This would remove the lossy handover noted in `LIFE-3`.
- **LIFE-6** `MUST` `verified` `F13 F14` - Not modify the interrupt routing `setupds` chose (INTA# mode, level-triggered setting in the PC's edge/level control registers, the card's interrupt line). A replacement that touches it can lose or stick interrupts.

## 5.2 Installation sequence

- **LIFE-7** `MUST` `verified` `F5 F16` - Order of events: (1) PCI BIOS check and card search (`HW-1`, `HW-2`); (2) the configuration writes of `HW-5` to `HW-7` and the read of `HW-8`; (3) take over the trap points (chapter 3); (4) become resident. Nothing may be trapped before step 2 completes, since the slave does not exist until then.
- **LIFE-8** `MUST` `verified` `F5 F16` - On success, stay resident with exit code 0 (observed in E16 with the original) and leave the DOS environment alone. A TSR cannot set `BLASTER` for its parent; the stock batch file sets it only in the branch that does not load the TSR, so users of the TSR branch must set it themselves (F13).
- **LIFE-9** `MUST` `inferred` `F5` - On failure (no PCI BIOS, no card, no VCPI, unsupported memory manager), print a clear message, make no changes to the card or the machine, and exit with a nonzero code. The original returns failure from its card-setup routine; the other failure paths were not exercised.
- **LIFE-10** `SHOULD` `untested` - Detect a second copy of itself already resident and refuse to install again.

## 5.3 Optional improvements (new behaviour, none of it in the original)

These are the improvements listed in the project roadmap. They are `MAY` and `untested` by definition.

- **LIFE-11** `MAY` `untested` `F2 F6` - Write the slave's **Master Clear** at install, and/or when the guest writes the 8237 master-clear port. Controlled by an option. Whether it should be on by default depends on the hardware tests (`DEC-1`).
- **LIFE-12** `MAY` `untested` - A status command that reports whether the TSR is resident, the hooked channel, the slave base and the number of trapped accesses handled.
- **LIFE-13** `MAY` `untested` - An unload command that restores the memory manager's tables and releases the memory (`TRAP-8`). The original cannot be unloaded.
- **LIFE-14** `MAY` `untested` - A diagnostic mode that logs trapped accesses (port, value, direction) to the console or a file.

## 5.4 Interaction with `setupds` that a user should know about

These are properties of the original package, repeated here so the replacement's documentation can state them.

- **LIFE-15** `MAY` `inferred` `F13` - Document that on a chipset `setupds` does not recognise, its own DMA self-test is expected to fail, because the card is not in D-DMA mode until the TSR loads (it leaves the DMA mode field at the reserved value). A failed self-test there does not by itself indicate a fault, and `setupds` does not change its exit code for it.
