# 5. Installation and lifecycle (`LIFE-`)

How the TSR is started, what it assumes about `setupds`, its defaults, and the improvements an open replacement could add.

## 5.1 Where it fits at boot

On a machine with an unrecognised chipset, Yamaha's `LOADTSR.BAT` runs `setupds /s`, which programs the card and exits with
code 2, and then runs the TSR with **no command line**. The replacement is a drop-in for that last step.

- **LIFE-1** `MUST` `verified` - Work when started with no arguments, taking its settings from the defaults in `LIFE-3`. The original's batch file never passes any.
- **LIFE-2** `MUST` `verified` - Assume `setupds /s` has already run: the legacy audio block has been configured, the card has been reset and clocked, and its interrupt has been routed. The TSR then only adds the D-DMA settings of chapter 1. It does not reset or power-cycle the card.
- **LIFE-3** `MUST` `verified` - Unless another source of settings is provided (`DEC-2`), use these defaults, which are the original's compiled-in values: Sound Blaster base 220h, hooked DMA channel 1, slave base `F390h`; the original's default interrupt is IRQ 5. The original never reads `ds.ini`, so settings chosen in `setupds` for any of these are not carried over. That is a limitation of the original, not a requirement.
- **LIFE-4** `SHOULD` `untested` - Accept command-line overrides for the Sound Blaster base (220h, 240h, 260h, 280h), the DMA channel and the slave base. The original reads its command line but nothing in its own batch file uses it, and the syntax was not recovered, so a replacement defines its own.
- **LIFE-5** `MAY` `untested` - Instead of fixed defaults, read what `setupds` already programmed into the card's configuration (the Sound Blaster base and DMA channel in 40h and 42h) and keep it. This would remove the lossy handover noted in `LIFE-3`.
- **LIFE-6** `MUST` `verified` - Not modify the interrupt routing `setupds` chose (INTA# mode, level-triggered setting in the PC's edge/level control registers, the card's interrupt line). A replacement that touches it can lose or stick interrupts.

## 5.2 Installation sequence

- **LIFE-7** `MUST` `inferred` - The card configuration (`HW-5` to `HW-7`, and the read of `HW-8` if made) must be complete before the first trapped access can reach the slave, since the slave does not exist until then. How the original orders the configuration against taking over the trap points was not established; the observed runs show only that both happen before it returns.
- **LIFE-8** `MUST` `verified` - On success, stay resident with exit code 0 (observed in an emulator run with the original) and leave the DOS environment alone. A TSR cannot set `BLASTER` for its parent; the stock batch file sets it only in the branch that does not load the TSR, so users of the TSR branch must set it themselves.
- **LIFE-9** `MUST` `inferred` - On failure (no PCI BIOS, no card, no VCPI, unsupported memory manager), print a clear message and exit with a nonzero code, leaving no half-installed traps. The original returns failure from its card-setup routine; the other failure paths were not exercised.
- **LIFE-10** `SHOULD` `untested` - Run every check that can fail (PCI BIOS, card search, VCPI and memory-manager support) before the first write to the card, so that a failure changes nothing on the machine. How the original orders these was not established (`LIFE-7`).
- **LIFE-11** `SHOULD` `untested` - Detect a second copy of itself already resident and refuse to install again.

## 5.3 Optional improvements (new behaviour, none of it in the original)

These are the improvements listed in the project roadmap. They are `MAY` and `untested` by definition.

- **LIFE-12** `MAY` `untested` - Write the slave's **Master Clear** at install, and/or when the guest writes the 8237 master-clear port. Whether to do this, and whether it is fixed or configurable, is decision `DEC-1`.
- **LIFE-13** `MAY` `untested` - A status command that reports whether the TSR is resident, the hooked channel, the slave base and the number of trapped accesses handled.
- **LIFE-14** `MAY` `untested` - An unload command that restores the memory manager's tables and releases the memory (`TRAP-8`). The original cannot be unloaded.
- **LIFE-15** `MAY` `untested` - A diagnostic mode that logs trapped accesses (port, value, direction) to the console or a file.

## 5.4 Interaction with `setupds` that a user should know about

These are properties of the original package, repeated here so the replacement's documentation can state them.

- **LIFE-16** `MAY` `inferred` - Document that on a chipset `setupds` does not recognise, its own DMA self-test is expected to fail, because the card is not in D-DMA mode until the TSR loads (it leaves the DMA mode field at the reserved value). A failed self-test there does not by itself indicate a fault, and `setupds` does not change its exit code for it.
