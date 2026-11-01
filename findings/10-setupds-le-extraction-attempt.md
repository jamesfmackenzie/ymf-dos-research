# Finding 10 — `setupds.exe` LE extraction: extension install attempt, pivoting to a custom parser

**Date**: 2026-10-08
**Status**: in progress. Documents what was tried and why it's being abandoned in favor of
a different approach, not a dead end for the overall goal.

## Confirmed facts about `setupds.exe`'s format

- 184,512 bytes total. `file` reports "MS-DOS executable, LE executable for MS-DOS, DOS4GW
  DOS extender" — a classic DOS4GW envelope: a small real-mode MZ stub followed by an
  embedded 32-bit protected-mode LE (Linear Executable) image.
- Ghidra's native MZ loader only imports the stub: **14,792 of 184,512 bytes** — confirmed
  via a quick `GhidraScript` reporting `getMemory().getSize()`. All the real application
  logic (menu UI, PCI config reads/writes, the chipset-DDMA-capability check that decides
  `LOADTSR.BAT`'s errorlevel branch, whatever `SOUND TEST` does) lives in the untouched LE
  payload.
- Standard `e_lfanew`-style pointer at file offset `0x3C` → `0x30A8`, where a genuine `'LE'`
  signature sits. Well-defined, not a proprietary mess — same convention PE files use for
  their DOS-stub-to-real-header pointer.
- Ghidra ships no built-in LE/LX loader (`MzLoader`, `NeLoader`, `PeLoader` exist; no LE/LX
  class anywhere in `Base.jar`).

## Extension install attempt — real project exists, didn't get working headlessly

Found `ghidra-lx-loader` (oshogbo/ghidra-lx-loader on GitHub), explicitly described as
supporting OS/2/DOS4GW/VxD LE/LX binaries, with a real compiled `LXLoader.class` inside its
release zip (not just source). Newest release (`1.7`, `20260420`) targets Ghidra `12.0.4` —
one minor version behind our installed `12.1.4`.

- Downloaded and extracted the release zip into
  `GHIDRA_INSTALL_DIR/Ghidra/Extensions/LXLoader/` per the project's own README.
- Ghidra's class searcher does pick up the extension's `ghidra_scripts` path, but **the
  `Loader` class itself never gets registered** — `-loader "Linear eXecutable Module
  Format"` (the display name extracted directly from the compiled class's string table)
  is rejected as "Invalid loader name specified" both before and after patching
  `extension.properties`' version string from `12.0.4` to `12.1.4`.
- Root cause suspected: Ghidra's module/extension discovery likely needs proper OSGi bundle
  metadata that only the GUI's "Install Extensions" dialog (or the project's own
  Docker-based build pipeline) produces correctly — a raw copy of the release zip's
  contents isn't sufficient for headless-only use.
- The project's own build process is Docker-based, pulling a pinned Ghidra dev image —
  real extra infrastructure (Docker install, full repo checkout) just to resolve a
  one-minor-version mismatch. No Homebrew-pinned older Ghidra version is available either
  (`brew info ghidra` only offers the current `12.1.4` formula).

## Decision: pivot to a custom minimal LE parser instead

Rather than keep fighting third-party extension packaging, write our own small Ghidra
script that parses just enough of the LE header/object table to pull out the real code
bytes and their load address, then imports that as a raw binary with `x86:LE:32:default`
(32-bit protected mode) set explicitly. This keeps the approach consistent with everything
else in this repo (small, self-contained scripts we control) and avoids a dependency with
real version-matching friction. The format itself is openly documented — the
`ghidra-lx-loader` project's own README links the authoritative spec
(`http://www.textfiles.com/programming/FORMATS/lxexe.txt`), which is the reference to build
the parser against.

## Next step

Write the custom LE-header/object-table parser, extract `setupds.exe`'s real code, import
into a fresh Ghidra program with the correct 32-bit language, and resume the actual
analysis goal (trace the chipset-DDMA-capability check and whatever `SOUND TEST` does).
