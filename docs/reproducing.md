# Reproducing the analysis

The repo ships our findings, short excerpts and test sources, but not the Yamaha binaries,
full disassemblies or decompiler dumps. Everything omitted can be regenerated from your own
copy of the driver package.

## 1. Get the binaries
```sh
samples/ymf744/fetch.sh        # downloads package.zip, verifies SHA-256, unpacks to samples/ymf744/extracted/
```
Needs `curl` and `unzip`. Expected hashes: `samples/ymf744/SHA256SUMS`.

## 2. Full disassembly of Dsdma.exe
```sh
tools/regen-listings.sh        # needs ndisasm (from nasm)
```
This writes `capture/listings/dsdma-ndisasm-fileoffset-basis.txt` (addresses are file offsets; code
starts at 0x200) and `capture/listings/dsdma-ndisasm-ip-basis.txt` (`ndisasm -b 16 -e 0x790`, so
address 0 is IP 0 of the code segment). Findings 15 and 21
quote IP-basis addresses (for example `0x1020`, the #GP handler). Output was produced with a
recent nasm release; instruction text could differ slightly with another version.

## 3. Excerpts
`findings/excerpts/` has the short excerpts our commentary relies on (each under ~35 lines,
IP-basis addresses). Longer ranges that earlier drafts pasted were removed. To view one,
open the IP-basis listing at the address below:

| Topic | Start (IP) |
|---|---|
| #GP handler and prefix decode | 0x1020 |
| Per-vector IDT stubs and common entry | 0x6880, 0x6C80 |
| VCPI wrappers | 0x67B9 |
| Port-trap registration / IOPM setup | 0x17DF |
| YMF module trap registrations | 0xA853 |
| Enter PM / return to V86 | 0xC6FF |
| Resume epilogue | 0x261A |
| INT 2Fh 1687h hook, client create | 0x41B0 |
| INT 2Fh 'KESB' hook | 0xC254 |
| INT 31h dispatcher, INT 30h service | 0x361D, 0x39AC |
| LDT functions | 0x4A7E |
| Real-mode / PM vector handling (0200-0205) | 0x51DE |
| Version / free-memory (0400, 0500) | 0x56ED |
| INT 31h stubs (0600-0A00) | 0x6052 |
| #PF demand commit | 0x5FBE |

## 4. Ghidra analysis
Install Ghidra (the notes used 12.1.4) and create a project, importing `Dsdma.exe` with the
MZ loader. The headless scripts in `tools/ghidra_scripts/` were run with
`analyzeHeadless <projdir> <proj> -process Dsdma.exe -postScript <Script>.java`, with output
captured from stdout. Their roles:

| Script | Purpose |
|---|---|
| `InspectDsdma.java` | Function list and INT/IN/OUT sites (Finding 4) |
| `VerifyAccessorLibrary.java`, `FillGapsAndRescan.java` | Force-disassemble the D-DMA accessor library |
| `FindDDMAEnableWrite.java`, `TraceInit.java`, `TraceDefaultsCallerAndDispatch.java` | Init sequence and the D-DMA enable write (Finding 5) |
| `AddLeObjects.java`, `DecompSetupds.java`, `FindSetupdsIO.java`, `ListRange.java` | `setupds.exe` after LE extraction (Findings 10-12) |

`setupds.exe` is a DOS/4GW LE executable. Ghidra's MZ loader only sees the real-mode stub,
so `tools/le/leparse.py` extracts the LE objects first; see Finding 10 and 11.

## 5. Dynamic tests (DOSBox-X harness)
The shared harness is in `harness/` (build script, runner, debugger driver, FAKEPCI stub); each
experiment lives in `experiments/NN-name/` with its own README. See `harness/README.md` for
prerequisites (DOSBox-X, nasm, mtools, a FreeDOS 1.3 floppy image, Jemm binaries) and
`experiments/README.md` for the finding-to-experiment index. Finding 20 additionally needs Open
Watcom's DOS/4GW, PMODE/W and DOS/32A.

`harness/verify.sh experiments/<NN>-<name>` re-runs an experiment and compares it with the stored results
(`ALL MATCH` on success). Experiments 16 and 21 also have a debugger-driven `verify.sh`.

The D-DMA slave is not emulated, so these runs verify the trap path and DPMI behaviour, not
the card.

## The `capture/` scratch directory
Several findings mention `capture/` (gitignored). It is a local working directory for
generated or third-party material: Ghidra projects and decompiler output (`capture/decomp/`),
extracted LE objects for `setupds.exe` (`capture/setupds_le/`), the DOSBox-X image and Jemm
binaries (`capture/dosbox/`), Open Watcom extender binaries (`capture/ext/`) and shallow
clones of SBEMU/VSBHDA for reading (`capture/sbemu/`). Create it yourself as you follow a
finding; nothing in it is needed to read the findings.
