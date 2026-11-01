# Datasheets

The two datasheets this research relies on, where to get them, and checksums to confirm you have the same files.
The PDFs are not included in this repository: they are third-party documents, so the repo links to them instead.

- **`piix4_82371ab_290562-001.pdf`** — Intel 82371AB (PIIX4) datasheet, Order Number
  290562-001, April 1997. The direct `intel.com` URL
  (`https://www.intel.com/Assets/PDF/datasheet/290562.pdf`) is dead (Akamai "Access Denied"
  — confirmed by inspecting the response body, not just an HTTP status). Fetched instead via
  the Wayback Machine's snapshot of that same URL, 2026-10-07. Verified authentic:
  `pdftotext` + grep confirms §8.5.2 "Distributed DMA", §4.1.17 `PDMACFG`, §4.1.18 `DDMABP`
  are all present and match independent summaries already in the earlier notes.
  Used as the canonical chipset-side D-DMA protocol reference —
  see [`piix4-ddma-reference.md`](piix4-ddma-reference.md).

- **`ymf724_yamaha.pdf`** — Yamaha YMF724(F) datasheet. Downloaded 2026-10-07 from
  `https://ftp.icm.edu.pl/Linux/alsa/manuals/yamaha/ymf724.pdf` (an ALSA-project-maintained
  mirror, the same one already cited by name in the maintainer's earlier notes). Used to
  resolve the PCI config offset `0x40` vs. `0x4C` discrepancy in Finding 5 — confirmed
  authoritative register definitions for Legacy Audio Control (`40-41h`), Extended Legacy
  Audio Control (`42-43h`), and D-DMA Slave Configuration (`4C-4Dh`).

## How to fetch
Fetch them from the sources above (the Intel one only via the
Wayback Machine snapshot of the original URL). SHA-256 of the copies used:
- `piix4_82371ab_290562-001.pdf` 93e3900796fee17c1294fceaf7215a2be4f707a79a6c7a6ae3d3cacf29665362
- `ymf724_yamaha.pdf` 39bc4e258c3402dee8bcf5790928c6465f35461f28fe3d02dd23a9f9e2173260
