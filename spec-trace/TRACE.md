# Spec trace map

*Maintained by hand; checked by `python3 spec-trace/check.py`.*

This file joins each requirement in [`../spec/`](../spec/) to the research that supports it. It exists so the spec can stay free of references to the research: the spec never points here, and this file points at the spec by ID only. **Whoever builds the replacement should not need, and is not meant to use, this file or anything it links to.** See [`../spec/README.md`](../spec/README.md).

`check.py` fails if a spec requirement has no row here, if a row has no requirement, if the level or evidence tag differs from the spec, if a `verified` row has no evidence, or if a referenced finding or experiment does not exist.

## Requirements

| ID | Level | Tag | Findings | Experiments | Datasheet | Notes |
|---|---|---|---|---|---|---|
| HW-1 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | - |  |
| HW-2 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md), [F16](../findings/16-dosbox-x-dynamic-verification.md), [F22](../findings/22-setupds-card-bring-up-sequence.md) | - | - | Device ID 000Dh and revision 03h seen on real hardware (F22). Other IDs not run. |
| HW-3 | SHOULD | untested | [F5](../findings/05-init-sequence-and-dma-enable.md) | - | - |  |
| HW-4 | MUST | inferred | [F5](../findings/05-init-sequence-and-dma-enable.md) | - | - |  |
| HW-5 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md) | [E16](../experiments/16-trap-verification/) | DS-Y | The write to 40h is conditional or absent: E16 shows no write with the stub reading 907Fh. Which it is was not determined. |
| HW-6 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md), [F13](../findings/13-end-to-end-synthesis.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | DS-Y | The 1000h result is a stub artefact. After `setupds /s` on a real YMF724F the dword at 40h is 9800_3F4Fh (F22, maintainer's unpublished dump), so 42h reads 9800h before the TSR and should read 9000h after. |
| HW-7 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | DS-Y | Blind write: F5 shows `MOV CX,[base]; AND CX,FFF0h; OR CX,1; write 4Ch` with no read of 4Ch. |
| HW-8 | MAY | verified | [F5](../findings/05-init-sequence-and-dma-enable.md) | - | - |  |
| HW-9 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md) | - | - |  |
| HW-10 | MUST | inferred | [F13](../findings/13-end-to-end-synthesis.md), [F14](../findings/14-irq-path-pci-inta-and-elcr.md) | - | - |  |
| HW-11 | MUST | verified | [F1](../findings/01-ndisasm-first-pass.md), [F2](../findings/02-comparison-vs-piix4-spec.md), [F4](../findings/04-ghidra-corroboration.md) | - | DS-I |  |
| HW-12 | MUST | verified | [F2](../findings/02-comparison-vs-piix4-spec.md), [F4](../findings/04-ghidra-corroboration.md) | - | - |  |
| HW-13 | MUST | verified | [F4](../findings/04-ghidra-corroboration.md) | - | - |  |
| HW-14 | MAY | untested | [F2](../findings/02-comparison-vs-piix4-spec.md), [F6](../findings/06-real-hardware-master-clear-test-protocol.md) | - | DS-I |  |
| HW-15 | MAY | untested | [F2](../findings/02-comparison-vs-piix4-spec.md) | - | DS-I |  |
| HW-16 | MUST | inferred | [F5](../findings/05-init-sequence-and-dma-enable.md), [F6](../findings/06-real-hardware-master-clear-test-protocol.md) | - | DS-Y |  |
| HW-17 | MUST | inferred | [F4](../findings/04-ghidra-corroboration.md) | - | - |  |
| EMU-1 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | [E16](../experiments/16-trap-verification/) | - | F16 IOPM diff: Jemm already traps C4-C7, D4, D6, D8-DE; the original adds C0, C2, D0, D2. C8-CF are in neither list, yet F15 lists handlers for C8, CA, CC, CE. Unresolved; see spec 7.2. |
| EMU-2 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md), [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | [E16](../experiments/16-trap-verification/) | - | F16: pass-through identical to baseline; F16 could not tell chain from re-issue; F20 leans to re-issue (inferred). |
| EMU-3 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-4 | SHOULD | untested | [F8](../findings/08-dsdma-never-reads-ds-ini.md) | - | - |  |
| EMU-5 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | [E16](../experiments/16-trap-verification/) | - |  |
| EMU-6 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-7 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-8 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - | F15 step 5: return value 0 means "unhandled" and the server's own handler runs (inferred from the 1060h/1068h lookup). |
| EMU-9 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-10 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-11 | MUST | verified | [F2](../findings/02-comparison-vs-piix4-spec.md) | [E16](../experiments/16-trap-verification/) | DS-I |  |
| EMU-12 | MUST | inferred | [F2](../findings/02-comparison-vs-piix4-spec.md) | - | DS-I |  |
| EMU-13 | MUST | verified | - | [E16](../experiments/16-trap-verification/) | - |  |
| EMU-14 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| EMU-15 | MAY | untested | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| TRAP-1 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | [E16](../experiments/16-trap-verification/) | - |  |
| TRAP-2 | MUST | verified | [F19](../findings/19-pm-client-io-trapping.md), [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | [E19](../experiments/19-pm-client-trapping/), [E20](../experiments/20-real-extenders/) | - |  |
| TRAP-3 | MUST | verified | [F19](../findings/19-pm-client-io-trapping.md) | [E19](../experiments/19-pm-client-trapping/) | - |  |
| TRAP-4 | MUST | verified | [F19](../findings/19-pm-client-io-trapping.md), [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | [E20](../experiments/20-real-extenders/) | - |  |
| TRAP-5 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | - |  |
| TRAP-6 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md), [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | - | - | F16: handler is IDT[13], ahead of Jemm's gate. F20: with QPIEMU loaded first, QPI callbacks were 0 even for unhooked ports (verified); re-issue rather than chain is inferred. |
| TRAP-7 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | [E16](../experiments/16-trap-verification/) | - |  |
| TRAP-8 | SHOULD | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | - | - |  |
| TRAP-9 | SHOULD | verified | [F17](../findings/17-qpiemu-vs-jemm-dma-port-overlap.md), [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | [E20](../experiments/20-real-extenders/) | - | E20 runs: A QPIEMU only; B QPIEMU then Dsdma; C Dsdma then QPIEMU (hangs in DOSBox-X); D as C without the V86 probe. |
| TRAP-10 | MUST | verified | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | - |  |
| TRAP-11 | MUST | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md) | [E16](../experiments/16-trap-verification/) | - |  |
| TRAP-12 | SHOULD | untested | [F20](../findings/20-real-extender-vs-dsdma-dpmi-host.md) | - | - |  |
| DPMI-1 | MUST | verified | [F19](../findings/19-pm-client-io-trapping.md), [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-2 | MUST | verified | [F19](../findings/19-pm-client-io-trapping.md) | [E19](../experiments/19-pm-client-trapping/) | - |  |
| DPMI-3 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-4 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | [E20](../experiments/20-real-extenders/) | - |  |
| DPMI-5 | SHOULD | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - | F21: up to 16 nested clients, error 8010h. Nesting was not run. |
| DPMI-6 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | [E21](../experiments/21-dpmi-host-counters/) | - |  |
| DPMI-7 | SHOULD | inferred | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-8 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | [E21](../experiments/21-dpmi-host-counters/) | - |  |
| DPMI-9 | MAY | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-10 | SHOULD | untested | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-11 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - | F21: 0501 allocates through VCPI; release at client exit was not read. |
| DPMI-12 | MAY | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-13 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-14 | MUST | verified | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| DPMI-15 | MUST | inferred | [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - | F21 lists IRQ reflection; software-interrupt routing is not stated there. |
| DPMI-16 | SHOULD | inferred | [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F21](../findings/21-dsdma-dpmi-host-anatomy.md) | - | - |  |
| LIFE-1 | MUST | verified | [F8](../findings/08-dsdma-never-reads-ds-ini.md), [F13](../findings/13-end-to-end-synthesis.md) | - | - |  |
| LIFE-2 | MUST | verified | [F13](../findings/13-end-to-end-synthesis.md) | - | - |  |
| LIFE-3 | MUST | verified | [F8](../findings/08-dsdma-never-reads-ds-ini.md), [F13](../findings/13-end-to-end-synthesis.md) | [E16](../experiments/16-trap-verification/) | - |  |
| LIFE-4 | SHOULD | untested | [F5](../findings/05-init-sequence-and-dma-enable.md), [F8](../findings/08-dsdma-never-reads-ds-ini.md) | - | - |  |
| LIFE-5 | MAY | untested | [F8](../findings/08-dsdma-never-reads-ds-ini.md), [F13](../findings/13-end-to-end-synthesis.md) | - | - |  |
| LIFE-6 | MUST | verified | [F13](../findings/13-end-to-end-synthesis.md), [F14](../findings/14-irq-path-pci-inta-and-elcr.md) | - | - |  |
| LIFE-7 | MUST | inferred | [F5](../findings/05-init-sequence-and-dma-enable.md), [F16](../findings/16-dosbox-x-dynamic-verification.md) | - | - | F5/F16 show the configuration and the trap takeover but not their order relative to each other. |
| LIFE-8 | MUST | verified | [F5](../findings/05-init-sequence-and-dma-enable.md), [F16](../findings/16-dosbox-x-dynamic-verification.md), [F13](../findings/13-end-to-end-synthesis.md) | [E16](../experiments/16-trap-verification/) | - |  |
| LIFE-9 | MUST | inferred | [F5](../findings/05-init-sequence-and-dma-enable.md) | - | - |  |
| LIFE-10 | SHOULD | untested | - | - | - |  |
| LIFE-11 | MAY | untested | [F2](../findings/02-comparison-vs-piix4-spec.md), [F6](../findings/06-real-hardware-master-clear-test-protocol.md) | - | - |  |
| LIFE-12 | MAY | untested | - | - | - |  |
| LIFE-13 | MAY | untested | - | - | - |  |
| LIFE-14 | MAY | untested | - | - | - |  |
| LIFE-15 | MAY | inferred | [F13](../findings/13-end-to-end-synthesis.md) | - | - |  |
| TEST-1 | MUST | verified | - | [E16](../experiments/16-trap-verification/) | - | Stub: offset 40h reads 907Fh, 42h reads 0. |
| TEST-2 | MUST | verified | - | [E16](../experiments/16-trap-verification/) | - |  |
| TEST-3 | MUST | verified | - | [E16](../experiments/16-trap-verification/) | - |  |
| TEST-4 | MUST | verified | - | [E16](../experiments/16-trap-verification/) | - |  |
| TEST-5 | MUST | verified | - | [E19](../experiments/19-pm-client-trapping/) | - |  |
| TEST-6 | MUST | verified | - | [E20](../experiments/20-real-extenders/) | - |  |
| TEST-7 | MUST | verified | - | [E21](../experiments/21-dpmi-host-counters/) | - |  |
| TEST-8 | SHOULD | verified | - | [E17](../experiments/17-qpiemu-port-overlap/), [E20](../experiments/20-real-extenders/) | - |  |
| TEST-9 | MUST | untested | [F6](../findings/06-real-hardware-master-clear-test-protocol.md), [F7](../findings/07-real-hardware-test-session-inconclusive.md) | - | - |  |
| TEST-10 | SHOULD | untested | [F6](../findings/06-real-hardware-master-clear-test-protocol.md), [F9](../findings/09-setupds-role-and-possible-warmup-source.md) | - | - | Protocol in F6; the competing explanation is in F13 (aborted self-test leaves a DSP command pending). |
| TEST-11 | SHOULD | untested | - | - | - |  |
| TEST-12 | SHOULD | untested | - | - | - |  |
| TEST-13 | SHOULD | untested | [F7](../findings/07-real-hardware-test-session-inconclusive.md) | - | - |  |

## How to run the emulator checks

These are the harness commands behind the `TEST-` checks (see [`../harness/README.md`](../harness/README.md)). They run the original; they are not meant to be pointed at a replacement without adapting them.

| Check | Command or section |
|---|---|
| TEST-1 | `harness/verify.sh experiments/16-trap-verification` (sections PCI, RC) |
| TEST-2 | sections T1 and T2 of experiments/16-trap-verification |
| TEST-3 | section T2 of experiments/16-trap-verification |
| TEST-4 | `experiments/16-trap-verification/debugger/verify.sh` (stepped trace, memory dumps) |
| TEST-5 | `harness/verify.sh experiments/19-pm-client-trapping` (runs 1 and 2) |
| TEST-6 | `harness/verify.sh experiments/20-real-extenders` (runs A and B) |
| TEST-7 | `experiments/21-dpmi-host-counters/verify.sh` (counting build of the original) |
| TEST-8 | experiments/20-real-extenders, runs B and C |

## References that sat in the spec outside requirement lines

Moved here from the spec prose, tables and decision notes. The line numbers are in the spec as it stood before the split (commit `534e42b`).

| Spec file:line | Text as it stood |
|---|---|
| 00-scope-and-terms.md:13 | See the diagram in the [project README](../README.md#background-what-these-programs-are-for). |
| 01-card-interface.md:5 | runs observed (E16). |
| 02-dma-emulation.md:26 | / Write address (00/02/04/06, two writes) / Track the byte-pointer flip-flop; write low then high byte to slave +0, +1 / verified (F15) / |
| 02-dma-emulation.md:27 | / Read address / Read slave +1, +0 and return the byte the flip-flop selects / verified (F2 F4) / |
| 02-dma-emulation.md:28 | / Write count (01/03/05/07, two writes) / As address, to slave +4, +5 / verified (F4 F15) / |
| 02-dma-emulation.md:29 | / Read count / Tear-safe read of slave +5, +4 (`HW-12`), returned a byte at a time / verified (F2 F4) / |
| 02-dma-emulation.md:30 | / Write page (83 for channel 1) / Store and write to slave +2 / verified (F15) / |
| 02-dma-emulation.md:31 | / Read page / Read slave +2 / verified (F4) / |
| 02-dma-emulation.md:32 | / Write mode (0B) with channel bits = hooked channel / Write to slave +Bh / verified (F4 F15) / |
| 02-dma-emulation.md:33 | / Read status (08) / Merge the slave's status with the real controller's (see `EMU-11`) / verified (F2 E16) / |
| 02-dma-emulation.md:34 | / Single-channel mask (0A), clear mask (0E), write-all-masks (0F) / Translate to a write of slave +Fh (see `EMU-12`) / inferred (F2) / |
| 02-dma-emulation.md:35 | / Write command (08) / Not forwarded to the slave by the original / inferred (F4) / |
| 02-dma-emulation.md:36 | / Write request (09) / Not forwarded to the slave by the original / verified (F1 F4) / |
| 02-dma-emulation.md:37 | / Master clear (0D) / Resets only the TSR's own software state in the original; no slave write / verified (F15) / |
| 02-dma-emulation.md:38 | / Clear flip-flop (0C) / Reset the TSR's flip-flop view for the controller / inferred (F15) / |
| 03-trap-mechanism.md:27 | The original is stacked on a VCPI memory manager. It makes the DMA ports fault by changing the manager's I/O permission bitmap, takes over the manager's fault handling from inside protected mode, hides VCPI from later programs and provides its own DPMI host. It does not use QPI, HDPMI's trap interface or any memory-manager API. (F15, F16, F21) |
| 03-trap-mechanism.md:34 | / Jemm QPI (port-trap callbacks) / yes / **no** (E19, E20 run D shows 0 callbacks) / verified; useful for diagnostics only / |
| 04-dpmi-host.md:5 | (F21 section 8). Requirements here apply to any design that provides its own DPMI host (`DEC-3`); a design that traps some other way |
| 04-dpmi-host.md:18 | Table of functions with the evidence for each. **Used** = called by the named extenders among DOS/4GW, PMODE/W, DOS/32A in E20/E21 (a lower bound: the counters saturate at 255 and the per-extender figures are differences between stops). **Implemented** = the original implements it but no tested extender called it. Tag rules as elsewhere: `verified` means the original's behaviour was seen; the *nee |
| 05-lifecycle.md:8 | code 2, and then runs the TSR with **no command line** (F8, F13). The replacement is a drop-in for that last step. |
| 07-open-questions.md:7 | - **DEC-1** - *Master Clear.* The original never writes the slave's Master Clear (`HW-14`) and never forwards the guest's master-clear port write. Whether the missing write causes the unreliable first DMA after load is an open hypothesis: the one hardware session was inconclusive (F7) and a clean run of the protocol in F6 is outstanding (`TEST-10`). Options include never writing it (as the origina |
| 07-open-questions.md:8 | - **DEC-2** - *Where settings come from.* The original ignores `ds.ini` and hardcodes its values; `setupds` choices are overwritten (F13). A replacement can keep the defaults (`LIFE-3`), accept a command line (`LIFE-4`), or read back what `setupds` programmed (`LIFE-5`). The last has not been tried. *Considerations:* fixed defaults reproduce the original and keep the TSR small. Command-line option |
| 07-open-questions.md:9 | - **DEC-3** - *Trap architecture.* Stack on VCPI with an own DPMI host (the original), or another way to meet `TRAP-1` to `TRAP-3` (chapter 3, table in 3.3). The first is the only one shown to work for protected-mode games (F19, F20); it couples the TSR to the memory manager's table layout and has been tested with Jemm only. *Considerations:* the stacked design needs a DPMI host (chapter 4) and hi |

## Things about the original deliberately kept out of the spec

These describe how the original is built, not what a replacement must do, so they are in the research and not in the spec.

- A second set of protected-mode tables the original builds and its code never obviously uses (a guess: a fallback for memory managers that do not expose the information it takes through VCPI): [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F21](../findings/21-dsdma-dpmi-host-anatomy.md).
- A check, over INT 2Fh, for a resident program with a particular signature, and calls to entry points when one answers; it looks like a hook for Yamaha's own tooling and nothing in the package provides it: [F15](../findings/15-how-dsdma-traps-the-8237-ports.md).
- A debug-register write during DPMI client setup, reason unknown: [F21](../findings/21-dsdma-dpmi-host-anatomy.md).
- That the original pays a fault for every access to the trapped ports, including unhooked channels, and whether removing those traps changes anything (spec `EMU-15`): [F15](../findings/15-how-dsdma-traps-the-8237-ports.md), [F16](../findings/16-dosbox-x-dynamic-verification.md).
- The decompile-level detail of how the card is brought up by `setupds /s`: [F22](../findings/22-setupds-card-bring-up-sequence.md).
