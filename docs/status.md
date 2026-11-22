# Status

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

## Specifications
`spec/` has three behavioural specifications: the DMA master TSR, the card setup tool (silent apply on a YMF724F only) and the
interaction between them. `spec-trace/check.py` checks their format and that each requirement has evidence in the trace map.
The interactive mode of the setup tool, other family members, and the vendor's interrupt-reporting tool and demo player are not
covered yet. Real-hardware validation of the warm-up hypothesis is outstanding.

## Tools
Static analysis: Ghidra, `ndisasm`. Dynamic: DOSBox-X with FreeDOS and Jemm. See
`docs/reproducing.md`.
