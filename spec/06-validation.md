# 6. Validation (`TEST-`)

How to tell whether an implementation meets this spec. Each check gives the inputs, the original's result (the baseline a replacement should reproduce) and what to look at. The original's results were obtained in an emulator; everything that depends on the real card needs hardware.

## 6.1 What an emulator can and cannot show

The original's results were obtained in DOSBox-X running FreeDOS 1.3 with Jemm 5.86 as the memory manager, with a **stub PCI BIOS** (section 0.4) that reports a fake YMF724F, so the TSR installs unmodified. The stub starts with PCI configuration offset 40h reading `907Fh` (SBEN set, DMA channel 1) and offset 42h reading `0000h`, and it logs every configuration write. **The D-DMA slave is not emulated**: reads of slave registers return FFh.
So such a setup can verify PCI programming, trapping, pass-through, VCPI hiding and the DPMI host, and cannot verify what the card does with the values written to it, nor audio.

## 6.2 Acceptance checks that can run in an emulator

- **TEST-1** `MUST` `verified` `E16` - **Installation.** Under Jemm with the stub PCI BIOS above, the TSR installs and returns 0. PCI configuration afterwards: offset 42h = `1000h` (an artefact of the stub, see `HW-6`) and offset 4Ch = `F391h`. The stub's log shows a write to 42h and a write to 4Ch. A write to 40h is allowed only if it leaves `907Fh` unchanged (`HW-5`).
- **TEST-2** `MUST` `verified` `E16` - **Pass-through.** After load, channels other than the hooked one return the same address, count, page and status-register values they returned before load. Cover channels 0, 2, 3 and 5, their page registers, and string I/O on an unhooked port.
- **TEST-3** `MUST` `verified` `E16` - **Hooked channel.** With the unbacked slave, reads of the hooked channel's address and count return FFFFh, the status register reads 22h (versus 00h before load), and the page register for the channel reads FFh.
- **TEST-4** `MUST` `verified` `E16` - **Trap path.** Under a debugger, a V86 `IN AL,02` is intercepted and the program resumes at the next instruction with the expected register values.
- **TEST-5** `MUST` `verified` `E19` - **VCPI is hidden.** A VCPI client started after the TSR loads is told VCPI is absent (INT 67h AX=DE00h returns AH=84h), whereas without the TSR it runs and its port accesses are not trapped.
- **TEST-6** `MUST` `verified` `E20` - **Extenders run.** A test program built for each of DOS/4GW, PMODE/W and DOS/32A, which reads back the hooked channel's address, status and page registers, runs to completion under the TSR at ring 3 and sees trapped results: address readback FFFFh, status 22h and page register FFh. Without the TSR (VCPI only) the same program runs at ring 0 and reads 3412h back, i.e. untrapped.
- **TEST-7** `MUST` `verified` `E21` - **API subset.** While those three extenders run, log every INT 31h function they call. The replacement must provide every function in `DPMI-6` and must not return an error for any function the extenders depend on. A replacement has to add its own call logging to do this.
- **TEST-8** `SHOULD` `verified` `E17 E20` - **Jemm trap order.** Loaded after QPIEMU, the TSR works and the extenders run. Loaded before QPIEMU, the original hangs a V86 probe in the emulator (`TRAP-9`); a replacement should not.

## 6.3 Checks that need hardware or real software

- **TEST-9** `MUST` `untested` `F6 F7` - **Real games on real hardware.** Doom and Duke Nukem 3D (DOS/4GW and its relatives, and Watcom-based extenders) start, play and exit with sound on a machine whose chipset has no D-DMA, under the TSR. The original's own results on this are recorded as inconclusive (F7).
- **TEST-10** `SHOULD` `untested` `F6 F9` - **The warm-up symptom.** On the reference machine the original shows an unreliable first DMA after load: Doom hangs at the end of its demo loop after a cold boot, and not if Duke Nukem 3D was run first. The symptom may be intermittent, so repeat each configuration several times. Compare the original, a replacement that writes the slave's Master Clear at install (`LIFE-11`), and a replacement that does not. The result is evidence for `DEC-1`.
- **TEST-11** `SHOULD` `untested` - **Other memory managers.** Repeat `TEST-1` to `TEST-7` under EMM386 and QEMM (`TRAP-12`).
- **TEST-12** `SHOULD` `untested` - **Other extenders.** Run a program built with Causeway and with an extender that wants DPMI 1.0 (`DPMI-10`).
- **TEST-13** `SHOULD` `untested` `F7` - **Quake.** The original's run of Quake crashed with an invalid-opcode fault under Jemm both before and after any change, apparently unrelated to DMA. A replacement should note whether it behaves the same; Quake is not part of `TEST-9` for that reason.
