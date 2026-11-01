# Finding 20 — Real DOS extenders (DOS/4GW, PMODE/W, DOS/32A) with and without Dsdma

**Date**: 2026-10-11
**Basis**: Finding 16 harness (DOSBox-X 2026.10.01, FreeDOS 1.3, Jemm 5.86 `JEMMEX V`, real
unmodified `Dsdma.exe` + `FAKEPCI.COM` stub). Extender runtimes and compiler come from the Open
Watcom v2 `Current-build` snapshot (`ow-snapshot.tar.xz`, `binw/`: `dos4gw.exe` (Rational DOS/4G,
strings "Rational Systems 1987-1993"), `pmodew.exe`, `dos32a.exe`); the test program was built with
`wcl386 -bt=dos -l=dos4g|pmodew|dos32a` run inside DOSBox-X. Binaries stay in gitignored
`capture/ext/`; only sources, scripts and logs are in `experiments/20-real-extenders/`.
Tags: **verified** = observed in this run; **inferred** = reasoning only; **not tested**.

## Test programs
- `xt.c` (one source, three extender builds): reads CS (CPL = CS&3) and EFLAGS IOPL; sets the ch1
  address 0x3412 via flip-flop (OUT 0C/02/02), reads it back (IN 02 x2), reads status (IN 08),
  does OUT 0A,05 / OUT 0B,45, IN 83, then re-masks ch1. Dsdma's hooked ch1 reads FF; the
  unhooked/Jemm-VDMA path reads back 3412.
- `qc.asm` (`QC.COM`): resident QPI callback (needs QPIEMU) trapping 02,08,0C,0A,0B,83 with
  pass-through (1A04) and a count/log, reported by `QC R`. Used to see whether V86 or PM I/O reaches
  QPIEMU callbacks.
- `DMAT.COM` (Finding 16) as the V86 baseline.

## Results
| Scenario | Extender | CPL | IOPL (pushfd) | ch1 addr rb | QPI callbacks |
|---|---|---|---|---|---|
| A: Jemm VCPI, QPIEMU+QC, **no Dsdma** | DOS/4GW | 0 | 0 | 3412 | none (count stays 0x17 = V86 DMAT only) |
| | PMODE/W | 0 | 0 | 3412 | none |
| | DOS/32A | 0 | 0 | 3412 | none |
| B: QPIEMU+QC, then FAKEPCI+**Dsdma** | DOS/4GW | **3** | 0 | **FFFF** (st 22) | none |
| | PMODE/W | **3** | 0 | **FFFF** | none |
| | DOS/32A | **3** | 0 | **FFFF** | none |
| D: FAKEPCI+Dsdma, **then** JLOAD QPIEMU+QC | all three | 3 | 0 | FFFF | none |

All **verified**. (`runA.txt`, `runB.txt`, `runD.txt`; DOS/4GW is run as `DOS4GW XT4G.EXE`.)

Conclusions:
1. (a) confirmed: without Dsdma all three real extenders run the app at CPL 0 under Jemm. In
   a V86-mode server that is only possible through VCPI (**inferred** from CPL 0; the extenders'
   verbose output does not name the interface). Its DMA-port I/O is not trapped: the QPI callback
   count does not move, and nothing is hooked by Dsdma (readback is the normal 3412).
2. (b) confirmed: with Dsdma loaded every extender runs the app at CPL 3 (so it took Dsdma's
   DPMI 0.90 host; VCPI is hidden by DE00->84h) and its port I/O is trapped by Dsdma:
   ch1 address reads FFFF, DMA status changes (00 -> 22), page-83 reads FF. Matches the
   Finding 16 V86 behaviour and Finding 19's DPMIT/PMT results, now with real DOS/4GW-class
   binaries. DOS/32A only warns about the mouse (9004), unrelated.
3. IOPL shows 0 in all cases; at CPL 3 that means port access is governed by the TSS IOPM,
   which is how Dsdma's bits take effect. At CPL 0 it is irrelevant.

## Coexistence with Jemm QPIEMU (new)
- **Dsdma pre-empts QPI callbacks for V86 as well.** With QPIEMU+QC loaded *before* Dsdma
  (scenario B), `DMAT` (V86) produced **count = 0** where scenario A gives 0x17 callbacks, even
  for ports Dsdma does not hook (0C, 08, 0A/0B, ch5 pass-through still returns correct data).
  So Dsdma's patched #GP stub sees every trapped port first, handles it, and resumes the client
  without calling Jemm's trap handler (verified: no QPI callbacks; **inferred**: it re-issues
  the real I/O itself rather than chaining to Jemm's saved gate). This answers the Finding 16
  open question "chain or re-issue" for the V86 path and means **QPIEMU and Dsdma cannot both
  own the DMA ports**; a QPIEMU-based TSR and Dsdma are mutually exclusive.
- Load order QPIEMU->Dsdma (B) and Dsdma->QPIEMU (D): both load (JLOAD succeeded, QC installed),
  extenders behave identically in both orders. In D, `DMAT` (V86) with QC installed **hung
  until the time limit** (run C: `V86.TXT` empty, nothing after it ran); cause not investigated
  (DOSBox-X or the QPI pass-through path under Dsdma's handler) - not tested further.
- QPI callbacks never fired for any PM client in any scenario (CPL0 VCPI untrapped, CPL3
  trapped by Dsdma not Jemm): consistent with Finding 19.

## Corrections to earlier findings
- Finding 19: its claims stand; "not tested: real DOS/4GW" is now tested (this finding).
  Add: Dsdma also pre-empts QPI callbacks for V86 ports.
- Finding 16 "chain or re-issue" open question is now leaning to re-issue (V86; see above).

## Not tested
EMM386/QEMM; an actual Doom/Duke3D binary (only a purpose-built probe); extender verbose output
naming VCPI/DPMI (DOS4G=verbose in DOSBox-X only prints its loader trace); how Dsdma's DPMI host
handles heavier DPMI API use (INT 31h services beyond what the extenders' startup used);
real hardware; DOS/32A/PMODE/W specific options (`DOS32A` env, `/vcpi`-style forcing).

## Repro
See `experiments/20-real-extenders/README.md`: with `capture/ext/` holding the extracted Watcom
`binw/` and the built `w/XT*.EXE`, run `harness/run-experiment.sh` on `autoexec/AUTOEXEC.A..D-*.BAT`.
