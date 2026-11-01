# 6. Validation (`TEST-`)

How to tell whether an implementation meets this spec. The emulator experiments in [`../experiments/`](../experiments/) already
exercise the original and can be pointed at a replacement; everything that depends on the real card needs hardware.

## 6.1 What the emulator harness can and cannot show

The harness (DOSBox-X, FreeDOS 1.3, Jemm 5.86; see [`../harness/README.md`](../harness/README.md)) runs the TSR with a stub PCI BIOS that
reports a fake YMF724F, so the TSR installs unmodified. **The D-DMA slave is not emulated**: reads of slave registers return FFh.
So the harness verifies PCI programming, trapping, pass-through, chaining and the DPMI host, and cannot verify what the card does
with the values written to it, nor audio.

## 6.2 Acceptance checks that can run in the harness

Each check lists the original's result (the baseline a replacement should reproduce) and the experiment that produces it.

- **TEST-1** `MUST` `verified` `E16` - **Installation.** Under Jemm with the stub PCI BIOS the TSR installs and returns 0. PCI configuration afterwards: offset 42h = `1000h` and offset 4Ch = `F391h`, and exactly those two writes in the stub's log (the stub's offset 40h already reads `907Fh`, so a conditional write to it does not show; see `HW-5`). Check: `harness/verify.sh experiments/16-trap-verification` (sections `PCI`, `RC`).
- **TEST-2** `MUST` `verified` `E16` - **Pass-through.** After load, channels other than the hooked one return the same address, count, page and status-register values they returned before load. Check: sections `T1` and `T2` of E16 (channels 0, 2, 3 and 5, page registers, string I/O on an unhooked port).
- **TEST-3** `MUST` `verified` `E16` - **Hooked channel.** With the unbacked slave, reads of the hooked channel's address and count return FFFFh, the status register reads 22h (versus 00h before load), and the page register for the channel reads FFh. Check: E16 `T2`.
- **TEST-4** `MUST` `verified` `E16` - **Trap path.** A V86 `IN AL,02` is intercepted and the program resumes at the next instruction. Check: `experiments/16-trap-verification/debugger/verify.sh` (stepped trace and memory dumps).
- **TEST-5** `MUST` `verified` `E19` - **VCPI is hidden.** A VCPI client started after the TSR loads is told VCPI is absent, whereas without the TSR it runs and is not trapped. Check: `harness/verify.sh experiments/19-pm-client-trapping` (runs 1 and 2).
- **TEST-6** `MUST` `verified` `E20` - **Extenders run.** The test program built for DOS/4GW, PMODE/W and DOS/32A runs to completion under the TSR at ring 3, and the hooked channel is trapped: address readback FFFFh, status 22h and page register FFh. Without the TSR (VCPI only) the same program runs at ring 0 and reads 3412h back, i.e. untrapped. Check: `harness/verify.sh experiments/20-real-extenders` (runs A and B).
- **TEST-7** `MUST` `verified` `E21` - **API subset.** Counting INT 31h calls while those three extenders run shows no function outside the union in `DPMI-6` that the TSR fails to provide. Check: `experiments/21-dpmi-host-counters/verify.sh` (needs the counting build of the TSR, which for a replacement means adding the same counters).
- **TEST-8** `SHOULD` `verified` `E17 E20` - **Jemm trap order.** Loaded after QPIEMU, the TSR works and the extenders run (E20 run B). Loaded before QPIEMU, the original hangs a V86 probe (E20 run C); a replacement should not.

## 6.3 Checks that need hardware or real software

- **TEST-9** `MUST` `untested` `F6 F7` - **Real games on real hardware.** Doom, Duke Nukem 3D and Quake (DOS/4GW and its relatives, and Watcom-based extenders) start, play and exit with sound on a machine whose chipset has no D-DMA, under the TSR. The original's own results on this are recorded as inconclusive (F7).
- **TEST-10** `MUST` `untested` `F6 F9` - **The warm-up symptom.** Following the protocol in Finding 6, check whether the first DMA use after load is unreliable and whether writing the slave's Master Clear at install (`LIFE-11`) changes that. The result decides `DEC-1`.
- **TEST-11** `SHOULD` `untested` - **Other memory managers.** Repeat TEST-1 to TEST-7 under EMM386 and QEMM (`TRAP-12`).
- **TEST-12** `SHOULD` `untested` - **Other extenders.** Run a program built with Causeway and with an extender that wants DPMI 1.0 (`DPMI-10`).
- **TEST-13** `SHOULD` `untested` `F7` - **Quake.** The original's run of Quake crashed with an invalid-opcode fault under Jemm both before and after any change, apparently unrelated to DMA; a replacement should note whether it behaves the same.
