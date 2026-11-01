# DOSBox-X test harness

Boots FreeDOS 1.3 in DOSBox-X with the Jemm memory manager, loads the real `Dsdma.exe`, and
runs small test programs that probe port trapping and DPMI behaviour. Used by Findings 16-21
(`experiments/`). The D-DMA slave is not emulated, so these runs test the trap path, not the card.

## Prerequisites
- `dosbox-x` 2026.10.01, `nasm`, `mtools` (mcopy/mdir/mtype), `python3` with `pyte` (for the debugger driver only)
- `samples/ymf744/fetch.sh` already run (provides `Dsdma.exe`)
- A `capture/dosbox/` working directory (gitignored) containing:
  - `fd13/144m/x86BOOT.img`: the FreeDOS 1.3 floppy base image
  - `jemm/`: Jemm v5.86 binaries (`JEMMEX.EXE`, `JEMM386.EXE`, `VCPI.EXE`, `JLOAD.EXE`, `QPIEMU.DLL`, `XMSSTAT.EXE`, `MEMSTAT.EXE`)
- Only for some experiments:
  - Finding 19: `HDPMI32.EXE`, `HDPMI16.EXE`, `HDPMI16i.EXE` (from HX 2.23 `HXRT223.zip`) placed in `capture/dosbox/`
  - Findings 20 and 21: run `harness/build_extenders.sh` (Open Watcom v2 tools and extenders land in `capture/ext/`: `binw/dos4gw.exe`, `pmodew.exe`, `dos32a.exe`, built `w/XT4G.EXE`, `XTPW.EXE`, `XT32.EXE`)

## Files
| File | Purpose |
|---|---|
| `build_image.sh` | Assembles every `src/*.asm` to `NAME.COM`, builds `capture/dosbox/boot.img` with Jemm, Dsdma and the tools |
| `run-experiment.sh` | Rebuilds the image, installs one experiment's `AUTOEXEC.BAT`, boots it and prints the result files |
| `verify.sh` | Runs every scenario in an experiment's `scenarios.txt` and compares the output with the stored results (via `compare.py`) |
| `compare.py` | Section-by-section comparison of two run outputs; `--norm regs,ticks` ignores values that legitimately vary between runs |
| `build_extenders.sh` | Downloads Open Watcom and builds the three extender test programs for Experiments 20 and 21 |
| `run.sh` | Boots the current image for up to N seconds (stopping early once the autoexec writes `DONE.TXT`) and prints the `*.TXT` files written inside it |
| `dbg.py` | Drives the DOSBox-X text debugger through a pty (breakpoints, memory dumps, register snapshots) |
| `dosbox-x.conf`, `CONFIG.SYS` | Emulated machine (Pentium, `core=normal`, XMS/EMS/UMB off) and `DEVICE=\JEMMEX.EXE V` |
| `src/fakepci.asm` | `FAKEPCI.COM`, an INT 1Ah PCI BIOS stub reporting a fake 1073:000D device so `Dsdma.exe` passes its probe unmodified |
| `src/brk.asm`, `src/mcbs.asm`, `src/dmat.asm` | Debugger stop point (INT 2Fh AX=BEEF), MCB dump, 8237 channel dump |

## Usage
```sh
# run and check everything an experiment stores (prints ALL MATCH on success)
harness/verify.sh experiments/20-real-extenders

# run one autoexec by hand
harness/run-experiment.sh experiments/16-trap-verification/autoexec/AUTOEXEC.BAT 60
```
For debugger runs: `cd capture/dosbox && ROWS=60 python3 ../../harness/dbg.py <script.txt> > out`.
Script verbs: `send <text>` | `raw <hex>` | `wait <s>` | `snap <name>` | `sh <cmd>`.

## Notes and gotchas
- A debugger run needs `BRK.COM` or `TRAPT.COM` in the AUTOEXEC so execution stops at the right place (`bpint 2f be ef`).
- Typical prologue: `send bpint 2f be ef`, `raw 1b5b31357e` (F5), `wait 6`, `raw 1b5b31357e`, `wait 45`.
- Paged `gdt`/`idt` debugger output blocks input; send `raw 71` (q) afterwards.
- `MEMDUMPBIN` wraps at 64K above 1 MB; use `DV <linear>`.
- DOSBox-X has no I/O-port breakpoints and does not log unbacked I/O.
- DOSBox-X stops at `-time-limit` by showing a modal "quit" dialog unless `quit warning=false` is set; `dosbox-x.conf` sets it and `run.sh` also force-kills after the limit plus 30 s.
- Every autoexec that is meant to finish ends with `ECHO DONE > DONE.TXT`; `run.sh` stops as soon as it sees it. Scenarios that hang by design never write it and run to the time limit.
- Never run two harness scripts at once: they share `capture/dosbox/boot.img`.
- `dbg.py` runs windowless (`SDL_VIDEODRIVER=dummy`) and needs `pip install pyte`.
- Stuck runs: `pkill -9 dosbox-x`.
