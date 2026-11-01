# Provenance — Yamaha YMF744 DOS driver package

The binaries are **not included in this repository**. Run `samples/ymf744/fetch.sh` to download
and verify them (expected hashes in `samples/ymf744/SHA256SUMS`).

- **Source**: Phil's Computer Lab, https://www.philscomputerlab.com/yamaha-ymf744-pci-sound-card.html
- **Direct URL**: https://www.philscomputerlab.com/uploads/3/7/2/3/37231621/yamaha_ymf744_dos_drivers_with_dsdma.exe_and_ymfirq.exe.zip
- **Downloaded**: 2026-10-07
- **File**: `package.zip`, 1,299,196 bytes
- **Contents** (`extracted/`): `CWSDPMI.EXE`, `DOS4GW.EXE`, `ds.ini`, `Dsdma.exe`,
  `Fmmidi.exe`, `loadtsr.bat`, `setupds.exe`, `ymfirq.exe`, `ymh.mid`, `Ymh16.wav`, `Ymh8.wav`.
- **Primary target**: `Dsdma.exe` (53,952 bytes, DOS timestamp 1999-05-13). Plain MS-DOS MZ
  executable, no extender/compression. `setupds.exe` is a DOS/4GW LE executable.

The Yamaha software is copyright its owners; findings in this repo are our own
observations and commentary.
