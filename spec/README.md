# Behavioural specifications: Yamaha YMF724 DOS bring-up

**Status: draft, not yet tagged.**

Three specifications describe what a DOS machine needs to make a Yamaha YMF724-family sound card work as a Sound Blaster when the
host chipset has no distributed DMA of its own. They say **what a replacement must do**, not how the original does it, so that
someone who has never seen the original programs can build a compatible one from these folders, the datasheets and the public
material listed below.

| Folder | Covers |
|---|---|
| [`dsdma/`](dsdma/) | The DMA master TSR: finding the card, the PCI configuration, emulating the 8237 ports, the trap mechanism, the DPMI host, lifecycle, validation, open questions. Prefixes `HW-`, `EMU-`, `TRAP-`, `DPMI-`, `LIFE-`, `TEST-`, `DEC-` |
| [`setupds/`](setupds/) | The card setup tool, silent-apply mode on a YMF724F only: bring-up sequence, legacy configuration, mixers, self-test, tear-down. Prefixes `SDS-`, `STEST-`, `SDEC-` |
| [`interaction/`](interaction/) | The contract between the two: ownership, the state at the hand-over, exit codes and boot flow, and the settings-file grammar. Prefixes `INT-`, `ITEST-`, `IDEC-` |
| [`INDEX.md`](INDEX.md) | Every requirement in one table (generated) |

Each folder has numbered chapters. Chapter 0 says what is in and out of scope and defines terms; the last chapter lists open
questions and the decisions an implementer must make. The `interaction/` specification refers to neither of the others; each of
the others refers to it. Any pairing works: a new setup tool with the original TSR, or the reverse.

**Not covered anywhere yet:** the setup tool's interactive mode, other YMF7xx family members, the vendor's interrupt-reporting tool
and the demo player shipped in the same package.

These folders stand alone. They do not refer to the research that produced them, and nothing in them should send a reader there.

## Requirement format

Each requirement is one line:

```
- **EMU-4** `MUST` `verified` `DS-I` - Text of the requirement.
```

- **Level** follows RFC 2119: `MUST`, `SHOULD`, `MAY`.
- **Evidence tag** says how well the fact behind the requirement is established:
  - `verified`: read in the original program, seen in an observed emulator run, or stated by a datasheet.
  - `inferred`: reasoned from verified facts but not itself observed.
  - `untested`: a proposal or an expectation nobody has exercised, including new features the original lacks.
- **Datasheet** (optional) names the datasheet that defines the register or behaviour: `DS-Y` = YMF724F, `DS-I` = Intel PIIX4.

## What is deliberately not in here

- No code, disassembly or internal addresses of the original programs. Where the original's behaviour matters, the spec states the
  behaviour a program can observe (a register value, a return code, a port result), not how it is produced.
- No message text or banners copied from the original. The settings-file grammar is specified because the two programs interoperate through it; the file's name is not.
- No claim about the cause of the "first DMA after load is unreliable" symptom. That stays an open hypothesis
  (decision `DEC-1` in `dsdma/`, and the open questions of `interaction/`).
- No references to the research behind it: no numbered notes, no links, no test scripts. Each check is stated as inputs and expected observable results.

## Provenance

The authors of these specifications had read the original programs; that is the reason for the rules above. The history of
this folder is the record of what an implementer was given.

## References you may use

- The YMF724F datasheet (Yamaha) and the Intel 82371AB PIIX4 datasheet (its Distributed DMA section). In the requirements, `DS-Y` and `DS-I` refer to them.
- The VCPI 1.0 and DPMI 0.9 specifications, and the Intel architecture manuals on V86 mode, the task state segment and the I/O permission bitmap.
- Open-source code: Jemm (a VCPI memory manager) and the documentation of its QPI interface, HDPMI, SBEMU, VSBHDA, and the Linux `ymfpci` sound driver (for register names).
