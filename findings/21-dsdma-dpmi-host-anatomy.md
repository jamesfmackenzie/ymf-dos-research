# Finding 21 — Anatomy of Dsdma's DPMI host (what a replacement TSR must provide)

**Date**: 2026-10-11
**Basis**: static read of `Dsdma.exe` (the IP-basis listing (`docs/reproducing.md`); IP = file offset - 0x790) plus
dynamic counting in the Finding 16/20 harness (DOSBox-X 2026.10.01, FreeDOS 1.3, Jemm 5.86 VCPI,
FAKEPCI.COM). Short excerpts in `findings/excerpts/` (INT 31h dispatch table, dispatcher, #PF commit); counter scripts and results in `experiments/21-dpmi-host-counters/`. No binaries
committed. Tags: **verified** = read in code or observed; **inferred** = reasoning only;
**not tested**.

## Summary
Dsdma is a complete **DPMI 0.9** host (not a stub): all 0.9 functions are implemented except
that a handful are success no-ops. It sits on top of the VCPI server (Jemm), hides VCPI from
clients, runs clients at ring 3 in its own LDT with demand-paged extended memory, and reflects
interrupts both ways. The **minimum** that real extenders needed (measured) is much smaller:
about 25 functions. The #PF hook is **demand-paged memory commit** (resolves the open question in
Findings 16/19).

## 1. Hooks installed (verified, `0xB164-0xB1B6`, registrar `0x651D`)
Slot table at `[0x78C0]`: count (max 0x50) then {vector, flag, handler} records; `0x651D` also patches the IDT gate.
| Vector | Handler | Role |
|---|---|---|
| INT 2Fh | 0x3432 | 1687h/1686h DPMI detect (168Ah falls through) |
| INT 67h | 0x34AF | DE00 -> AH=84h (hides VCPI) |
| INT 30h | 0x39AC | internal service for raw-mode switch / callback return stubs |
| INT 31h | 0x361D | DPMI API; V86 callers are ignored (returns) |
| #PF (0Eh) | 0x5FBE | demand commit of DPMI linear memory |
| #GP (0Dh) | 0x1020 | DMA port trap (Findings 15/16) |
| INT 01h | 0x34D1 | single-step: sets RF/IF, clears TF |
| INT 21h | 0x341C | only notes AH=4Bh (exec) in `[0x778A]` |
| 16 hardware IRQs | 0x3389 | IRQ reflection into the client (via `0x6654`) |
PIC bases come from VCPI DE0A and are passed back to DE0B unchanged: **no PIC remap**.

## 2. INT 2Fh 1687h (verified)
Returns AX=0, BX=1 (32-bit clients OK), CL=CPU type `[78BA]`, DX=005A (0.90), SI=0400 paragraphs
(16 KB per-client data), ES:DI = real-mode template copy (ES=`[788C]>>4`, DI=0). `[0x7796]` is only
compared (inferred 0, hooks always active).

## 3. Mode switch (verified entry; internals partly read)
The entry is a real-mode template at IP 0x2A08 copied to low memory at `[788C]`:
`pushad; pushf; push segs; mov esi,imm; jmp far`. It enters PM through VCPI DE0C; client creation
is `0x41B0-0x42F0` (up to **16 nested clients**, error 8010; each a zeroed 0x4000-byte block with
its own descriptor table; 16/32-bit mismatch with parent gives 8002). Not fully traced: the exact
DE0C sequence at `0x2A22/0x2BB5/0x485C`.

## 4. INT 31h dispatch (verified; `int31-dispatch-table.txt`)
`0x361D` tests the VM bit, then indexes the top table `0x7797` by AH (0..0Bh); each sub-table is
{max AL, handlers}. Unknown AH/AL gives AX=8001, CF=1. Client frame at `[0x7788]`.
| Group | Status |
|---|---|
| 0000 alloc LDT, 0001 free, 0002 seg->desc, 0003 inc value (returns 8), 0006-000D get/set base/limit/rights, alloc at, dup | **full** |
| 0004, 0005 | **error** (8001) |
| 0100-0102 DOS memory | full |
| 0200-0205 RM/PM vectors, exceptions | full |
| 0300-0306 simulate int/call, RM callbacks, raw-switch addresses | full |
| 0400 version | full (005A, BX=1, CL=cpu, DX=0870) |
| 0500 free info, 0501 alloc, 0502 free, 0503 resize | full (below) |
| 0600-0603 lock/unlock | **no-op success** |
| 0604 page size | full (0x1000) |
| 0700, 0701 | **error** (8001); 0702-0703 | **no-op success** |
| 0800 physical map | full |
| 0900-0902 virtual IF | full (manipulates real IF in client EFLAGS) |
| 0A00 vendor API | **error** (8001) |
| 0B00-0B03 watchpoints | error 8016/8023 (not supported) |
| All DPMI 1.0 (0401, 0506/0507, 0210+, 0E00...) | absent (8001) |

## 5. LDT and extended memory (verified)
- LDT: bitmap allocator `0x3218`, selectors from 0x80 in 8-byte steps; new descriptors are DPL3
  data (0xF2) with the 32-bit flag if the client is 32-bit. Errors 8011 (none free), 8021, 8022.
- Linear memory: **0500** uses VCPI DE03 (free pages) minus a reserved count `[0x7780]`, base linear
  0x40000000, unknown fields 0xFFFFFFFF. **0501** is a first-fit scan of the client's page tables
  from PDE 0x100 (0x40000000), marking PTEs 0x806 ("allocated, not present"; bits 0x200/0x400 mark
  block start/continuation). **0502/0503** reuse the same helpers. **0800** maps physical ranges by
  writing PTEs (flags 0x7F). Errors 8012/8013/8023.
- **#PF handler `0x5FBE`**: for faults in 0x40000000-0x7FFFFFFF where the PTE is allocated, takes a
  page via VCPI DE04, writes PTE |0x67, decrements `[0x7780]`, flushes the TLB (invlpg, or CR3
  reload on a 386); anything else is declined. 0502 returns pages through DE05. So memory is
  **committed lazily**. The PTE writer at `0x6779` was not examined.

## 6. Interrupts (verified, `0x2F24`, `0x3389`)
- Software INT emulation: V86 caller gets an IRET frame and the IVT target; PM caller gets a frame
  on the client stack (16/32-bit) and the handler from the PM vector table `[0x768A]` (6-byte
  entries); exception table `[0x768E]`, 0x1F entries.
- 0200/0201 write the low-memory IVT via FS; 0204/0205 edit the PM table.
- Hardware IRQ: `0x3389` switches to the client context, pushes an IRET frame, runs the client's PM
  handler (`0x2D2C`), records the IRQ number at +0x2F3. Virtual PIC bases reported as 8/0x70.
- 0300 uses `0x2923/0x308E/0x2F24/0x2D2C/0x2A4E/0x2C70`; INT 30h (`0x39AC`) dispatches by
  return-address range (table `0x7831`, stubs `0x3760+2n`) for raw switch and callback return.

## 7. Ring-3 PM #GP vs V86
The Finding 15/16 handler `0x1020` serves both: V86 faults arrive via the stub, and DPMI clients
run at CPL3 with IOPM-trapped ports (Findings 19/20). **Still open**: whether the PM path
decodes IN/OUT on a separate code path (the `0xAC46` "second environment" is unexplained).

## 8. What is minimal, and who would fail
Measured by counting INT 31h calls (patched `DSDMAL.EXE`, counter cave in `lg31.asm`), running the
Finding 20 test program (`xt`) built for each extender (counts saturate at 255):
| Extender | Functions used (counts) |
|---|---|
| DOS/4GW | 0000:113 0001:123 0003:1 0006:230 0007:56 0008:60 0009:66 000A:1 000B:121 000C:59 0200:255+ 0201:39 0202:64 0203:77 0204:255+ 0205:255+ 0300:2 0302:255+ 0303:1 0304:1 0305:1 0306:1 0400:1 0500:21 0501:11 0502:4 0506:1* 0600:31 0702:21 0A00:1* |
| PMODE/W (delta) | 0000:6 0006:1 0007:6 0008:6 0009:6 0300:35 0303:1 0304:2 0400:1 0501:3 0600:1 |
| DOS/32A (delta) | 0000:4 0001:3 0006:1 0007:4 0008:5 0009:4 0202:15 0203:30 0300:38 0400:2 0501:5 0600:1 |
`*` failed with 8001 and tolerated. **Union** (verified): 0000-0003, 0006-000C, 0200-0205, 0300,
0302-0306, 0400, 0500-0502, 0600, 0702. Real games will add DOS memory (0100-0102), 0503, 0800,
0900-0902 (**not exercised**, trivial test program). Never exercised: 0002, 000D, 0100-0102, 0301,
0503, 0604, 0800, 0900-0902, 0B00-0B03. 32-bit clients: verified for all three.
Likely failures for a minimal host (**inferred, not tested**): Causeway, and anything needing 1.0
calls (0401, 0506, 0E00) or the vendor API without a fallback; EMM386/QEMM/real-hardware **not tested**.

## 9. Size estimate (inferred)
DPMI-related code spans about IP 0x2900-0x6490, roughly 14-15 KB of the 16-bit image (0xCB30 total);
per-handler sizes from address deltas are inflated by interleaved helpers. A from-scratch host
limited to the measured union plus 0100-0102/0503/0800/0900-0902 is a few hundred lines of asm/C
for the INT 31h layer, plus the mode switch, reflection and demand paging: roughly **1.5-2.5 kloc
equivalent, complexity dominated by the mode switch, IRQ reflection and the VCPI/page-table
handling**; full 0.9 parity would add LDT/RM-callback details. Not measured.

## 10. Corrections to earlier findings
- Finding 16 (#PF "purpose not traced") and Finding 19 (#PF/`0xAC46` guessed as client machinery):
  the #PF is demand commit of DPMI linear memory, not related to the DMA trap. `0xAC46` remains
  unexplained.
- Finding 19: "small DPMI host" understated; it is a full 0.9 host with 16 nested clients.

## Open
Mode-switch internals (DE0C), `0x6C80` IRQ dispatch, PTE writer `0x6779`, `0xAC46`, `0x1934`
splitter, 'KESB' hook, DR3/DR7 at `0x27ED`; Causeway, EMM386, QEMM, real games, hardware.

## Key excerpts
- [`excerpts/int31-dispatcher-361D.txt`](excerpts/int31-dispatcher-361D.txt) — INT 31h dispatcher head
- [`excerpts/int31-dispatch-table.txt`](excerpts/int31-dispatch-table.txt) — function dispatch table
- [`excerpts/pf-demand-commit-5FBE.txt`](excerpts/pf-demand-commit-5FBE.txt) — #PF lazy commit

Other ranges are listed by start address in `docs/reproducing.md`.
