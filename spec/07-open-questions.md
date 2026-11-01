# 7. Open questions and decisions

## 7.1 Decisions an implementer must make

These are choices the evidence does not settle. Each says what is known and what would settle it. They are not requirements.

- **DEC-1** - *Master Clear.* The original never writes the slave's Master Clear (`HW-14`) and never forwards the guest's master-clear port write. Whether the missing write causes the unreliable first DMA after load is an open hypothesis: the one hardware session was inconclusive (F7) and a clean run of the protocol in F6 is outstanding (`TEST-10`). Until it is run, implement it as an option (`LIFE-11`), default off, so behaviour matches the original; flip the default if the hardware test supports it.
- **DEC-2** - *Where settings come from.* The original ignores `ds.ini` and hardcodes its values; `setupds` choices are overwritten (F13). A replacement can keep the defaults (`LIFE-3`), accept a command line (`LIFE-4`), or read back what `setupds` programmed (`LIFE-5`). The last is the least surprising for users but has not been tried.
- **DEC-3** - *Trap architecture.* Stack on VCPI with an own DPMI host (the original), or another way to meet `TRAP-1` to `TRAP-3` (chapter 3, table in 3.3). The first is the only one shown to work for protected-mode games; it couples the TSR to the memory manager's table layout and has been tested with Jemm only.
- **DEC-4** - *How much DPMI.* The measured need is about 25 functions (`DPMI-6`); the original has the full 0.9 API. Decide whether to stop at the measured set plus the likely extras (`DPMI-7`) or to add DPMI 1.0 for extenders that want it (`DPMI-10`).
- **DEC-5** - *Which channels.* Fixed hooked channel 1 as in the original, or a configurable one (`EMU-4`). Channels 5-7 (16-bit DMA) have only been read, not run.

## 7.2 Things nobody knows yet

Facts about the original that the findings did not establish. None blocks the requirements above, but each might matter for compatibility.

- **Second protected-mode environment.** The original builds a second set of tables that its code never obviously uses. A guess is a fallback for memory managers that do not expose the information it normally takes through VCPI. Not explained (F15, F21).
- **Why unhooked-channel ports still fault.** The original pays a fault for every access to the trapped ports, including the unhooked channels' ports, which it then passes to the hardware. Whether removing those traps changes anything is untested (`EMU-15`).
- **A read of the Sound Blaster DSP status port.** One routine in the original's slave-access code reads the register at offset Eh from the Sound Blaster base, which is the DSP's read-buffer status. Its purpose is unclear (F4 mystery 1).
- **The debug hook.** The original checks for a resident program that answers a particular signature over INT 2Fh and, if one answers, calls a set of entry points on certain interrupts. It looks like a hook for Yamaha's own tooling. Nothing in the package provides it.
- **Debug-register use.** The original writes a debug register during DPMI client setup. The reason is unknown (F21).
- **Why Dsdma-then-QPIEMU hangs.** Loading the original and then Jemm's QPIEMU makes a V86 DMA probe hang (F20 run C). The cause has not been traced (`TRAP-9`).
- **Which PCI device IDs the original accepts.** Only vendor 1073h, device 000Dh has been run (`HW-3`).
- **The slave's per-channel layout.** The datasheets describe a base pointer plus a channel field; the original uses base plus a fixed offset for its one channel (`01-card-interface.md`). Whether other channels would sit at other offsets is unknown because no other channel has been hooked.
- **Extender coverage beyond three.** DOS/4GW, PMODE/W and DOS/32A work. Causeway, other extenders, EMM386, QEMM and real games were not run.
- **Hardware behaviour.** The emulator has no slave. Everything the card does with the values it receives (including what a missing Master Clear does) is untested.
