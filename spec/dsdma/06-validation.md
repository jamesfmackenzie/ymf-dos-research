# 6. Validation (`TEST-`)

How to tell whether an implementation meets this spec. Each check gives the inputs, the original's result (the baseline a replacement should reproduce) and what to look at. The original's results were obtained in an emulator; everything that depends on the real card needs hardware.

## 6.1 What an emulator can and cannot show

The original's results were obtained in DOSBox-X running FreeDOS 1.3 with Jemm 5.86 as the memory manager, with the **stub PCI BIOS** below, so the TSR installs unmodified. The **slave is unbacked**: reads of slave registers return FFh. So such a setup can verify PCI programming, trapping, pass-through, VCPI hiding and the DPMI host, and cannot verify what the card does with the values written to it, nor audio.

**The stub PCI BIOS used for the baseline results:**
- INT 1Ah AX=B101h: AL=01h, BX=0210h, EDX=`PCI ` (20494350h).
- AX=B102h: finds vendor 1073h, device 000Dh and returns bus 0, device 0Bh, function 0 (BX=0058h); any other request returns device-not-found.
- AX=B108h to B10Dh: read and write configuration bytes, words and doublewords for that function only, backed by a 256-byte array, and log every write (offset, size, value).
- Initial configuration contents: vendor 1073h, device 000Dh, revision 03h, class 04h and subclass 01h (offsets 0Ah and 0Bh), offset 40h = `907Fh` (SBEN set, DMA channel 1), offset 3Ch = 05h (interrupt line), offset 3Dh = 01h (INTA#); everything else 0, including offset 42h.

## 6.2 Acceptance checks that can run in an emulator

- **TEST-1** `MUST` `verified` - **Installation.** Under Jemm with the stub PCI BIOS above, the TSR installs and returns 0. PCI configuration afterwards: offset 42h = `1000h` (specific to this stub, whose offset 42h starts at 0; a real card gives a different value, see `HW-6`) and offset 4Ch = `F391h`. The stub's log shows a write to 42h and a write to 4Ch. A write to 40h is allowed only if it leaves `907Fh` unchanged (`HW-5`).
- **TEST-2** `MUST` `verified` - **Pass-through.** Run a real-mode program that reads, before the TSR is loaded and again after, the address and count ports of channels 0, 2, 3 and 5 (00, 01, 04-07, C4, C6), the page registers 81, 82, 87, 89, 8A, 8B, and does a `REP INSB`/`OUTSB` round trip on port 04. Every value after load must equal the value before load.
- **TEST-3** `MUST` `verified` - **Hooked channel.** On the unbacked slave, a real-mode (V86) program that clears the flip-flop (`OUT 0Ch`) and reads port 02 twice reads FFFFh, reading the status register (port 08) gives 22h (versus 00h before load), and reading the page register (port 83) gives FFh.
- **TEST-4** `MUST` `verified` - **Trap path.** Under a debugger that can single-step, a V86 `IN AL,02` executed after load passes through the TSR's fault handler and the next instruction then runs with AL = FFh (unbacked slave).
- **TEST-5** `MUST` `verified` - **VCPI is hidden** (for a design that hides VCPI, `TRAP-3`, `DPMI-2`). A minimal VCPI client started after the TSR loads issues INT 67h AX=DE00h and is told VCPI is absent (AH=84h). Without the TSR it gets AH=00h, can enter protected mode through VCPI, and its reads of the DMA ports are not trapped.
- **TEST-6** `MUST` `verified` - **Extenders run.** Build one test program for each of DOS/4GW, PMODE/W and DOS/32A that executes: `OUT 0Ch,0`; `OUT 02h,12h`; `OUT 02h,34h`; `OUT 0Ch,0`; `IN 02h` twice (low byte, then high byte); `IN 08h`; `OUT 0Ah,05h`; `OUT 0Bh,45h`; `IN 08h`; `IN 83h`; `OUT 0Ah,01h`; `OUT 0Ah,05h`; and reports the low two bits of CS (the privilege level) and the values read. Under the TSR it runs to completion at privilege level 3 and reads address FFFFh, status 22h and page FFh. Without the TSR (VCPI only) the same program runs at privilege level 0 and reads address 3412h, i.e. untrapped.
- **TEST-7** `MUST` `verified` - **API subset** (for a design that provides its own DPMI host, chapter 4). While the three extenders of `TEST-6` run, log every INT 31h function they call, by adding counters to the replacement's own host or by a debugger. Every function called must be in `DPMI-6`, or be one the extenders tolerate an error from (`DPMI-8`).
- **TEST-8** `SHOULD` `verified` - **Jemm trap order.** Loaded after QPIEMU, the TSR works and the extenders of `TEST-6` run. Loaded before QPIEMU, the original hangs a V86 DMA probe in the emulator (`TRAP-9`); a replacement should not.

## 6.3 Checks that need hardware or real software

- **TEST-9** `MUST` `untested` - **Real games on real hardware.** Doom and Duke Nukem 3D (DOS/4GW and its relatives, and Watcom-based extenders) start, reach their menu or demo, play audible sound effects and music and exit to DOS without a hang, on a machine whose chipset has no D-DMA, under the TSR. No result for the original is established.
- **TEST-10** `SHOULD` `untested` - **The warm-up symptom.** The reference machine is the one on which the original showed an unreliable first DMA after load: a Supermicro X10SAE with a YMF724F, where Doom hangs at the end of its demo loop after a cold boot and does not if Duke Nukem 3D was run first. The symptom may be intermittent, so repeat each configuration enough times to tell (for example ten cold boots each). Compare the original, a replacement that writes the slave's Master Clear at install (`LIFE-12`), and a replacement that does not. The result is evidence for `DEC-1`.
- **TEST-11** `SHOULD` `untested` - **Other memory managers.** Repeat `TEST-1` to `TEST-7` under EMM386 and QEMM (`TRAP-12`).
- **TEST-12** `SHOULD` `untested` - **Other extenders.** Run a program built with Causeway and with an extender that wants DPMI 1.0 (`DPMI-10`).
- **TEST-13** `SHOULD` `untested` - **Quake.** The original's run of Quake crashed with an invalid-opcode fault under Jemm both before and after any change, apparently unrelated to DMA. Record whether a replacement crashes the same way; this is information, with no pass or fail outcome. Quake is not part of `TEST-9` for that reason.
