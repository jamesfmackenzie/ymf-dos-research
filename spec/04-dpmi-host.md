# 4. DPMI host (`DPMI-`)

A design that traps by stacking on a VCPI memory manager must also be the **DPMI host** for 32-bit DOS programs (`TRAP-3`).
This chapter says how much of DPMI that takes. The original is a complete DPMI 0.9 host; the measured need is much smaller
(section 4.2). Requirements here apply to any design that provides its own DPMI host (`DEC-3`); a design that traps some other way
(`TRAP-2` met differently) is not bound by them. How much of the API to provide is `DEC-4`.

## 4.1 Detection and entry

- **DPMI-1** `MUST` `verified` - Answer INT 2Fh AX=1687h as a DPMI host: AX=0; BX bit 0 set (32-bit programs supported); CL = processor type; DX = `005Ah` (version 0.90); SI = paragraphs of private data the program must provide per client; ES:DI = the real-mode entry point for the switch to protected mode. Also answer AX=1686h (running in protected mode).
- **DPMI-2** `MUST` `verified` - Answer INT 67h AX=DE00h with AH=84h so that no later program sees VCPI (`TRAP-3`).
- **DPMI-3** `MUST` `verified` - Ignore INT 31h calls made from V86 mode (return without effect). Only protected-mode clients use the API.
- **DPMI-4** `MUST` `verified` - Run each client at ring 3 with its own descriptor table, so that its port I/O is governed by the I/O permission bitmap (`TRAP-2`). Hardware interrupts must reach the client's protected-mode handlers, and the virtual PIC bases the client sees are those of the memory manager (observed 08h and 70h): do not remap the PICs.
- **DPMI-5** `SHOULD` `verified` - Support nesting: a DPMI client that executes another DPMI program (for example a game launching its setup program) should work. The original allows 16 nested clients and returns error 8010h beyond that (read in its code). No test launched one DPMI program from another, so the need is inferred.

## 4.2 INT 31h functions

Table of functions with the evidence for each. **Used** = called by the named extenders among DOS/4GW, PMODE/W, DOS/32A in the emulator runs (a lower bound: the counters saturate at 255 and the per-extender figures are differences between stops). **Implemented** = the original implements it but no tested extender called it. Tag rules as elsewhere: `verified` means the original's behaviour was seen; the *need* for a function that no tested extender calls is `untested`.

| AH:AL | Function | Need | Original's behaviour |
|---|---|---|---|
| 0000 / 0001 | Allocate / free LDT descriptors | **Used** (0000: all three; 0001: DOS/4GW, DOS/32A) | full |
| 0002 | Segment to descriptor | Implemented | full |
| 0003 | Selector increment value | **Used** (DOS/4GW) | returns 8 |
| 0006-0009 | Descriptor base and limit: 0006 get base, 0007 set base, 0008 set limit, 0009 set access rights | **Used** (all three) | full |
| 000A | Create alias descriptor | **Used** (DOS/4GW) | full |
| 000B / 000C | Get / set descriptor | **Used** (DOS/4GW) | full |
| 000D | Allocate specific LDT descriptor | Implemented | full |
| 0004 / 0005 | (reserved in 0.9) | n/a | error 8001h |
| 0100-0102 | Allocate / free / resize DOS memory block | Implemented | full |
| 0200 / 0201 | Get / set real-mode interrupt vector | **Used** (DOS/4GW) | full, reads and writes the interrupt table |
| 0202 / 0203 | Get / set exception handler | **Used** (DOS/4GW, DOS/32A) | full |
| 0204 / 0205 | Get / set protected-mode interrupt vector | **Used** (DOS/4GW) | full |
| 0300 | Simulate real-mode interrupt | **Used** (all three) | full |
| 0301 | Call real-mode procedure with far return | Implemented | full |
| 0302 | Call real-mode procedure with IRET frame | **Used** (DOS/4GW) | full |
| 0303 / 0304 | Allocate / free real-mode callback | **Used** (DOS/4GW, PMODE/W) | full |
| 0305 | Get state save/restore addresses | **Used** (DOS/4GW) | full |
| 0306 | Get raw mode switch addresses | **Used** (DOS/4GW) | full |
| 0400 | Get DPMI version | **Used** (all three) | AX=005Ah, BX=1 (32-bit), CL=CPU type, DX=PIC bases (08h, 70h) |
| 0500 | Get free memory information | **Used** (DOS/4GW) | full |
| 0501 / 0502 | Allocate / free memory block | **Used** (0501: all three; 0502: DOS/4GW) | full |
| 0503 | Resize memory block | Implemented | full |
| 0600 / 0601 | Lock / unlock linear region | **Used** (0600: all three) | succeeds, does nothing |
| 0602 / 0603 | Mark / relock real-mode region | Implemented | succeeds, does nothing |
| 0604 | Get page size | Implemented | 1000h |
| 0700 / 0701 | (reserved in 0.9: page demand hints) | n/a | error 8001h |
| 0702 / 0703 | Mark page as demand-paging candidate / discard | **Used** (DOS/4GW) | succeeds, does nothing |
| 0800 | Map physical address range | Implemented | full |
| 0900 / 0901 / 0902 | Virtual interrupt state | Implemented | full (changes the client's interrupt flag) |
| 0A00 | Vendor-specific extension lookup | Called by DOS/4GW, **failure tolerated** | error 8001h |
| 0B00-0B03 | Debug watchpoints | Not exercised | error (8016h / 8023h): not supported |
| 0506 | Get page attributes (DPMI 1.0) | Called by DOS/4GW, **failure tolerated** | error 8001h |
| other 1.0 (0401, 0507, 0E00...) | DPMI 1.0 | Not exercised | error 8001h |

- **DPMI-6** `MUST` `verified` - Implement every function marked **Used**. Measured union: 0000, 0001, 0003, 0006-000C, 0200-0205, 0300, 0302-0306, 0400, 0500-0502, 0600, 0702.
- **DPMI-7** `SHOULD` `inferred` - Also implement the functions marked **Implemented**: DOS-memory functions (0100-0102), resize (0503), physical mapping (0800) and virtual interrupt state (0900-0902) are likely to be called by real games even though the small test program does not. The original provides all of them; no real game has been run.
- **DPMI-8** `MUST` `verified` - For a function the host does not support, return with carry set and AX=8001h ("unsupported function"). DOS/4GW is known to call 0506 and 0A00 and carry on after that error.
- **DPMI-9** `MAY` `verified` - Make the lock/unlock (0600-0603) and demand-paging hint (0702/0703) functions no-ops that report success.
- **DPMI-10** `SHOULD` `untested` - Provide DPMI 1.0 functions (0401, 0506/0507, 0E00 and others) if a target game's extender needs them; Causeway-based programs are suspected to. Not tested.

## 4.3 Memory

- **DPMI-11** `MUST` `verified` - Allocate extended memory for 0501 from the memory manager's pages (through VCPI in the original) and return it to the manager on 0502. Returning it at client exit is expected but was not read.
- **DPMI-12** `MAY` `verified` - Commit pages lazily: the original reserves the address range at allocation and takes a page from the manager on the first touch, through a page-fault handler. Committing eagerly at allocation is also allowed (`untested`).
- **DPMI-13** `MUST` `verified` - Report allocation failures with the DPMI error codes (8012h linear memory unavailable, 8013h physical memory unavailable, 8023h invalid handle) and descriptor failures with 8011h (descriptor unavailable), 8021h (invalid value) and 8022h (invalid selector).
- **DPMI-14** `MUST` `verified` - Allocate selectors as ring-3 data descriptors, with the 32-bit default flag set when the client is a 32-bit program.

## 4.4 Interrupts

- **DPMI-15** `MUST` `inferred` - Reflect hardware interrupts into the client's protected-mode handler (set with 0205), and software interrupts raised by a protected-mode client to the real-mode vector (set with 0201) unless the client has installed a protected-mode handler (0204). The original reflects hardware interrupts (read in its code); the software-interrupt routing is the DPMI 0.9 rule and was not read separately.
- **DPMI-16** `SHOULD` `inferred` - Emulate `CLI`, `STI` and moves to and from control and debug registers for ring-3 clients, since these instructions fault at ring 3 without full I/O privilege. The original's fault handler decodes them; the exact policy for each was not read.
