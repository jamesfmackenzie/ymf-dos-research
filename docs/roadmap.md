# Status and roadmap

## What is established (see the findings for evidence and tags)
- `Dsdma.exe` configures the card and acts as a D-DMA master by trapping 8237 DMA ports in
  software (VCPI host takeover, I/O permission bitmap, #GP handler). It hooks one channel
  (default channel 1) and passes the rest through.
- It never reads `ds.ini` and never issues a D-DMA Master Clear or Request.
- It hides VCPI and acts as a DPMI 0.9 host so protected-mode DOS extenders run under its
  trap. Real DOS/4GW, PMODE/W and DOS/32A behave this way in our tests (DOSBox-X + Jemm).
- Jemm's QPI port-trap interface covers V86 code only; it does not reach protected-mode
  clients.

## Open questions
- **Is the missing Master Clear the cause of the "first DMA use after load is unreliable"
  symptom?** Not established. A real-hardware attempt was inconclusive (Finding 7) and the
  protocol in Finding 6 still needs a clean run.
- Behaviour with EMM386, QEMM and real games (Doom, Duke Nukem 3D, Quake) is untested.
- Unexplained parts of `Dsdma.exe`: the second PM environment (0xAC46), the string splitter
  (0x1934), the 'KESB' INT 2Fh debug interface, and a debug-register write (0x27ED).
- Why loading Dsdma and then QPIEMU makes a V86 DMA probe hang (Finding 20).

## Planned work
1. **Behavioural spec** (`spec/`): requirements for a replacement TSR derived from the
   findings and the chipset/card datasheets, with each requirement tagged verified, inferred
   or untested. Frozen and tagged before any implementation starts.
2. **OpenDSDMA**: an open-source replacement implemented from the spec only, in a separate
   repository. Candidate improvements over the original: honour `ds.ini` or command-line
   settings, explicit Master Clear, status and unload commands, diagnostics, more YMF PCI IDs.
3. **Real-hardware validation** of the warm-up hypothesis and of the replacement.

## Design directions for the replacement (not decided)
- **Own DPMI host plus I/O-bitmap/#GP trap** (the pattern `Dsdma.exe` uses). The only
  approach shown here to catch protected-mode games. Finding 21 lists the INT 31h subset
  needed (about 25 functions measured with three extenders, plus a few extra for real games).
- **HDPMI with its port-trap API**: untested here.
- **Jemm QPI**: V86-only, useful for diagnostics; cannot coexist with `Dsdma.exe` on the same ports.
- Design ideas (not code) may be borrowed from SBEMU/VSBHDA (GPL-2.0), see Finding 18.

## Tools
Static analysis: Ghidra, `ndisasm`. Dynamic: DOSBox-X with FreeDOS and Jemm. See
`docs/reproducing.md`.
