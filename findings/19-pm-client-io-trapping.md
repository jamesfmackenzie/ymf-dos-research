# Finding 19 — Do I/O traps reach protected-mode clients? (VCPI client vs DPMI client)

**Date**: 2026-10-10
**Basis**: DOSBox-X 2026.10.01 (core=normal, Pentium), FreeDOS 1.3 + `JEMMEX.EXE` (Jemm 5.86), same
harness as Findings 16/17. New test programs `experiments/19-pm-client-trapping/src/pmt.asm` (VCPI PM client) and
`experiments/19-pm-client-trapping/src/dpmit.asm` (16-bit DPMI client); logs `results/run1..run4-*.txt`, autoexecs `autoexec/AUTOEXEC.run*.BAT` in that folder.
HDPMI16/16i from HX 2.23 `HXRT223.zip` (GitHub release of Baron-von-Riedesel/HX), not committed.
Tags: **verified** = observed this run; **inferred** = reasoning; **not tested**.

## Headline
1. A **pure VCPI protected-mode client is not trapped at all**, by neither Jemm's own IOPM, nor QPIEMU
   callbacks, nor (by construction) Dsdma's IOPM/#GP hook. It runs at CPL 0 with IOPL 3 in its own
   tables; port I/O goes straight to the hardware.
2. **Dsdma therefore does not trap VCPI clients, because it prevents there being any.** Its INT 67h
   hook answers `AX=DE00h` with `AH=84h` (VCPI not present), and its INT 2Fh hook answers
   `AX=1687h` as a **DPMI 0.90 host**. DOS/4GW-class extenders find a DPMI host, run as a ring-3
   DPMI client, and their port I/O hits the IOPM that Dsdma controls. Findings 3 and 15 were wrong
   to describe Dsdma as sitting "below" the extender layer and being extender-agnostic.
3. **QPIEMU callbacks do not fire for protected-mode clients** of either kind (VCPI ring 0, or
   HDPMI ring 3, with HDPMI IOPL 3 or IOPL 0). The QPI-primary design from Findings 15–18 covers
   real-mode/V86 programs only.

## Test 1 — VCPI PM client under plain Jemm (`pmt.asm`)
Client follows Jemm's `Tools/VCPI/VCPI.ASM`: DE00, own page directory/table, DE01 (`restab`
descriptors), own GDT/IDT/TSS, DE0C into PM; own IDT has a #GP/#PF handler that logs the error code
and returns to V86. In PM it runs `IN 02, IN 04, IN ED, IN 83`; the same battery is run from V86
before and after. Run 1 (`run1-jemm-vcpi-client.txt`):

| | V86 before | PM client | V86 after |
|---|---|---|---|
| Jemm only (`PMT V`) | 00 00 FF 00 | 00 00 FF 00, CS.RPL=0, SS.RPL=0, EFLAGS=00003046 (IOPL=3), no #GP | 00 00 FF 00 |
| + QPIEMU trapping port 02 (`PMT Q`) | **A5** 00 FF 00 | **00** 00 FF 00, no #GP | **A5** 00 FF 00 |

QPI callback count = 2 (the two V86 `IN 02`s); the PM `IN 02` did **not** call it (**verified**; the
callback forces AL=A5). Ports 02/04/83 are in Jemm's IOPM (Finding 16) yet the PM client reads them
untouched, and no exception reached the client's IDT.

## Test 2 — Dsdma loaded (`run2-dsdma.txt`)
- `PMT V` after `DSDMA`: `DE00 failed AX=8400` (**verified**). VCPI is hidden from every later client.
- `DPMIT` (INT 2F/1687 client) with no Dsdma: "no DPMI host" (Jemm provides none). After `DSDMA`:
  `flags=0001 (32-bit ok) cpu=0005 ver=005A (0.90) paras=0400 entry=1193:0000`, the PM switch succeeds,
  **CS.RPL=3**, and `IN 02/04/ED/83` from PM gives `FF 00 FF FF`, identical to V86 (ch1 and page 83
  hooked → FF, ch2 passes through) (**verified**). So the PM client's I/O is trapped by Dsdma, at ring 3.
- Code (**verified in disassembly**, the IP-basis listing (`docs/reproducing.md`)): INT 2Fh hook `0x3432` (compares
  `[0x7796]` to 0; AX=1687h → returns AX=0, BX=1, DX=005A (DPMI 0.90), CL from `[0x78BA]`, SI=0400 paragraphs, entry ES from `[0x788C]>>4`, DI=0;
  AX=1686h returns 0/1 by VM flag; 168Ah falls through). INT 67h hook `0x34AF`: `AX==DE00h` → `AH=84h`.
  INT 31h dispatch `0x361D` is indexed by AH 0..0Bh with per-AH sub-tables at `0x7797` (the DPMI 0.9
  function groups). `[0x7796]` is only ever compared in the code I disassembled (no direct write found),
  so I infer it stays 0 and both hooks are always active (**inferred**; not run with it set).
- Dsdma is thus a DPMI host layered on Jemm's VCPI. **Corrected by Finding 21:** it is a full DPMI
  0.9 host (not small); the #PF hook is demand commit of extended memory; `0xAC46` remains unexplained.

## Test 3 — HDPMI (`run3`, `run4`)
- HDPMI16 `-r` under Jemm (`H0.TXT`: "now resident", VCPI mode): DPMI client at CS.RPL=3; PM `IN 02` →
  `00` and **callback count unchanged** (**verified**). Its docs say standard builds run clients with
  IOPL 3 so IN/OUT "are executed in real time" (HDPMI.TXT §6.13).
- HDPMI16**i** (IOPL 0 build, clean run 4): same: PM `IN 02`=00, no callback. So even where HDPMI
  could trap, nothing is forwarded to Jemm's QPI (**verified**; whether HDPMI faulted-and-emulated or
  not, QPI never saw it).
- HDPMI32 refuses a 16-bit client entry (switch fails, CF=1); not investigated further. Not tested:
  32-bit client, VSBHDA's HDPMI-trap API.
- Caveat for run 3: callback registered by a finished program stays in QPIEMU (stale), so run 4 is
  the clean one for the HDPMI16i result. Always `JLOAD -u` or reboot between tests.

## Test 4 — Jemm source (`Jemm `src/VCPI.ASM``, **verified by reading**)
`VCPI_V86toPM` (DE0C) does `mov cr3`, `lidt` (l.377), `lgdt` (l.379), `lldt` (l.380) and `ltr`
(l.392) from the **client's** V86TOPM structure; the server's TSS and IOPM are not active while the
client runs. Return to V86 (l.433) pushes EFLAGS `20002h or (V86IOPL shl 12)` with `V86IOPL equ 3`
(`JEMM.INC:55`). A PM client runs at the CPL its CS descriptor says (0 in my test, and DOS/4GW is
likewise a ring-0 VCPI client by VCPI's design), so IOPL is moot. Matches the observations.

## What is *not* tested
- No real DOS/4GW, DOS/32A, PMODE/W binary here (not in the repo; not downloaded). That DOS/4GW
  uses VCPI when no DPMI host answers, and DPMI when one does, is from HDPMI.TXT §6.13 and general
  knowledge (**inferred**; I did not run an extender). Doom/Duke3D behaviour under Dsdma is
  therefore consistent but not reproduced.
- 32-bit DPMI client; Dsdma DPMI features beyond the mode switch and `IN`; EMM386/QEMM; real hardware.

## Consequences (feeds PLAN Phase 8 / DECISIONS)
- **QPIEMU primary route is insufficient for DOS/4GW titles by itself.** With Jemm + QPI TSR only,
  and no DPMI host, DOS/4GW goes VCPI at ring 0 and its DMA programming hits the real 8237
  ports (no Dsdma-style redirection, no callback). Hooking after the fact cannot fix it: the client
  loads its own CR3/IDT/TSS.
- Options for covering PM clients: (a) **Dsdma pattern**: hide VCPI (INT 67h DE00 → 84h) and be the
  DPMI host with an IOPM/#GP monitor; (b) a real host plus its trap hook (HDPMI via the VSBHDA-style
  `hdpmi` port-trap API, untested, HDPMI-specific; stock HDPMI doesn't trap on its own); (c) intercept
  the client's DE0C and substitute/patch its tables or TSS IOPM (the more invasive VCPI-level hook,
  not seen in Dsdma, untested). Choice of (a) vs (b) is open; (a) is what the original does.
- QPIEMU remains attractive for real-mode games and as the V86 half of a hybrid design.

## Corrections made
Finding 3 (extender-agnostic claim, "sits below" argument), Finding 15 (trap placement caveats,
`Q` about hooks), Finding 18 (top-risk item resolved: answer is no). See each file's update note.
