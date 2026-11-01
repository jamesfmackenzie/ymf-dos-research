# OpenDSDMA behavioural specification

**Status: draft, not yet tagged.** The plan is to freeze it as tag `spec-v1` after review, before any implementation starts.

This is a specification for a replacement of Yamaha's `Dsdma.exe`: a DOS TSR that acts as a software Distributed DMA
master for YMF724/744 sound cards. It says **what the replacement must do**, not how the original does it. It is written
so that someone who has never seen the original program, and does not intend to, can build a compatible one from
this folder, the two datasheets (see [`../docs/datasheets.md`](../docs/datasheets.md)) and open-source references.

If you are new to the subject, read the [project README](../README.md) first.

## How to read it

| File | Covers |
|---|---|
| [`00-scope-and-terms.md`](00-scope-and-terms.md) | What the replacement is for, what it is not, who does what, vocabulary, how requirements are written |
| [`01-card-interface.md`](01-card-interface.md) | `HW-`: finding the card, the PCI configuration it needs, the slave register layout |
| [`02-dma-emulation.md`](02-dma-emulation.md) | `EMU-`: which 8237 ports are emulated and how each one behaves |
| [`03-trap-mechanism.md`](03-trap-mechanism.md) | `TRAP-`: what must be intercepted, for which kinds of programs, and how to coexist with a memory manager |
| [`04-dpmi-host.md`](04-dpmi-host.md) | `DPMI-`: the DPMI host a trap-based design must provide, down to the INT 31h functions |
| [`05-lifecycle.md`](05-lifecycle.md) | `LIFE-`: installation order, defaults, exit codes, relation to `setupds`, optional improvements |
| [`06-validation.md`](06-validation.md) | `TEST-`: acceptance checks, with the emulator experiments that already exercise them |
| [`07-open-questions.md`](07-open-questions.md) | What is not known, and the decisions an implementer has to make |
| [`INDEX.md`](INDEX.md) | Every requirement in one table (generated) |

## Requirement format

Each requirement is one line:

```
- **EMU-4** `MUST` `verified` `F15 E16` - Text of the requirement.
```

- **Level** follows RFC 2119: `MUST`, `SHOULD`, `MAY`.
- **Evidence tag** says how well the fact behind the requirement is established:
  - `verified`: seen directly in the original program's disassembly, in an observed emulator run, or stated by a datasheet.
  - `inferred`: reasoned from verified facts but not itself observed.
  - `untested`: a proposal or an expectation nobody has exercised, including new features the original lacks.
- **Basis** points to the evidence: `F<n>` = [Finding n](../findings/), `E<n>` = [Experiment n](../experiments/),
  `DS-Y` = YMF724F datasheet, `DS-I` = Intel PIIX4 datasheet.

`python3 spec/check.py` validates the format, regenerates `INDEX.md` and warns if anything that looks like an internal
address of the original program has crept in. Run it after editing.

## What is deliberately not in here

- No code, disassembly or internal addresses of `Dsdma.exe`. Where the original's behaviour matters, the spec states the
  behaviour a program can observe (a register value, a return code, a port result), not how it is produced.
- No message text, banners or file layouts copied from the original.
- No claim about the cause of the "first DMA after load is unreliable" symptom. That stays an open hypothesis
  ([`07-open-questions.md`](07-open-questions.md), decision `DEC-1`).

## Provenance

The people who wrote this spec had read the original program's disassembly; that is the reason for the rules above and for
building the replacement in a separate repository, from this spec only. The history of this folder is the record of what
the implementer was given.
