# 0. Scope and terms

## 0.1 Purpose
Some PCI sound cards (Yamaha YMF724/744, the DS-1 family) emulate a Sound Blaster for DOS software but cannot do ISA
DMA. They offer **Distributed DMA (D-DMA)** instead: the card holds its own copy of one DMA channel's registers (the
*slave*), and a *master* is supposed to redirect the CPU's accesses to the legacy 8237 ports to that slave. Intel's PIIX4
and some other chipsets do this in hardware. Where the chipset does not, a TSR has to be the master, in software.

The replacement ("OpenDSDMA") is that TSR. Its job, in one sentence: **make a DOS program that programs the PC's DMA
controller for the Sound Blaster channel, in real mode, V86 mode or under a DOS extender, end up programming the card's
slave registers, and leave every other DMA channel alone.**

See the diagram in the [project README](../README.md#background-what-these-programs-are-for).

## 0.2 Out of scope
- Chipsets that already provide D-DMA or PC/PCI DMA. `setupds` programs those and the TSR is not loaded.
- Emulating a Sound Blaster, OPL3 or MPU-401 in software. The card's own hardware does that.
- Windows, WDM or any non-DOS environment.
- Moving audio data. In D-DMA the peripheral is the bus master and moves the data itself (DS-I section 8.5.2).
- Supporting cards other than the YMF724/744 family (see `HW-3`).

## 0.3 Who does what

| Component | Role |
|---|---|
| Game / Sound Blaster driver | Programs the DMA controller (ports 00-0F, 81-8B, C0-DE) and the Sound Blaster at its I/O base |
| `setupds` (Yamaha, unchanged) | Configures the card (legacy audio block, interrupts, power), runs a self-test, and exits with code 2 on a chipset it does not recognise so that the batch file loads the TSR |
| **OpenDSDMA** | Switches the card to D-DMA mode, enables the slave, then intercepts the DMA port accesses and forwards them to the slave |
| Memory manager (EMM386, Jemm, QEMM) | Provides V86 mode, extended memory and (in the original design) VCPI |
| Card | Implements the slave registers, the Sound Blaster block and bus-master data movement |

## 0.4 Vocabulary
- **8237**: the PC's DMA controller. DMA1 serves channels 0-3 (ports 00-0F), DMA2 serves channels 4-7 (ports C0-DE, even addresses).
- **Page registers**: ports 81, 82, 83, 87 (channels 2, 3, 1, 0) and 89, 8A, 8B (channels 6, 7, 5). Port 80 (delay) and 8F are not page registers for this purpose.
- **Hooked channel**: the one channel (normally 1, the Sound Blaster's) whose accesses are redirected to the slave.
- **Slave base**: the I/O address at which the card's slave registers appear. Default `F390h`.
- **Trap**: making an I/O instruction raise a CPU fault instead of reaching hardware (via the I/O permission bitmap in V86 or ring-3 code).
- **VCPI / DPMI**: the two DOS interfaces for 32-bit protected-mode programs. VCPI runs the client with full privilege next to the memory manager; DPMI runs it at ring 3 under a host.
- **Original**: Yamaha's `Dsdma.exe` version 1.00 as shipped in the YMF744 DOS driver package.

## 0.5 Conventions
- Hex numbers use an `h` suffix (`F390h`) in prose. Ports and PCI offsets are for the card and the PC, not internals of any program.
- "Observed" means the behaviour of the original, as established by the findings.
- A requirement that says "as the original" is a compatibility requirement, not a recommendation to copy anything else.
- The requirement format and evidence tags are defined in [`README.md`](README.md).
