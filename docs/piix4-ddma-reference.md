# PIIX4 Distributed DMA — primary-source reference

Source: Intel 82371AB (PIIX4) datasheet, Order Number 290562-001, April 1997.
Source and checksum: [`datasheets.md`](datasheets.md) (the PDF is not included in this repo)
(fetched via the Wayback Machine — intel.com no longer serves this doc directly).
§8.5.2 "Distributed DMA", pp. 168–170. §4.1.17–4.1.18 for the chipset-side config registers.

This is the canonical description of how a *real* chipset (acting as DMA master) is
supposed to drive the registers a D-DMA-capable sound card exposes. `DSDMA.exe` plays
the same master role in software, on a chipset that has no DDMA hardware at all. Every
claim below is what correct behavior looks like — the baseline to diff the disassembly
against.

## Chipset-side config (PIIX4 Function 0 PCI config space — not present on a modern chipset)

- **`PDMACFG`, offset `90h–91h`**: 2 bits per DMA channel (0,1,2,3,5,6,7 — channel 4 reserved/unavailable)
  select `00`=Normal ISA DMA, `01`=PC/PCI DMA, `10`=Distributed DMA, `11`=Reserved.
- **`DDMABP`, offset `92h–93h`** (channels 0–3) and **`94h–95h`** (channels 5–7): base I/O
  address pointer to the peripheral's relocated DMA slave registers. Bits `[15:6]` are the
  base address; bits `[5:0]` reserved (64-byte window, 16 bytes/channel × 4 channels).
  *"It is up to the BIOS or other configuration software to program the DDMA peripherals
  to the corresponding locations."* — i.e. the peripheral (sound card) must be told this
  same base address independently; nothing propagates it automatically.

## The handshake itself (§8.5.2 narrative, quoted)

> "The Distributed DMA (DDMA) scheme is based on the concept that the registers associated
> with individual DMA can physically reside outside of PIIX4, specifically on other PCI
> devices. The Distributed DMA logic in PIIX4 is only used when the CPU does accesses to
> the 8237 registers. **Data movement is the responsibility of the peripheral.**"

**Read cycle**, CPU reads a legacy 8237 port on a DDMA-configured channel:
1. PIIX4 issues a PCI retry to terminate the CPU's cycle.
2. PIIX4 requests the bus, performs one or more read cycles against the peripheral
   (address per formula below) and/or the real 8237.
3. PIIX4 merges those reads into the proper 8237-shaped data value.
4. When the CPU retries, PIIX4 returns that value.

**Write cycle**, CPU writes a legacy 8237 port on a DDMA-configured channel:
1. PIIX4 issues a PCI retry to terminate the CPU's cycle.
2. PIIX4 requests the bus, writes the CPU's value through to the peripheral and/or the
   real 8237, at the same calculated address.
3. When the CPU retries, PIIX4 lets it complete normally.

**This is exactly the shape `DSDMA.exe` must replicate without chipset hardware**: trap the
CPU's I/O instruction to the legacy port *before* it reaches anything (there is no PIIX4 to
issue a bus retry — this is why DSDMA.exe needs V86/EMM386-class port-trapping instead),
translate the access to the peripheral's real I/O address via the formula below, and either
return the read value or forward the write — then let the CPU's instruction appear to have
completed normally against real 8237-shaped registers.

## Address calculation (the formula a software master must reimplement)

```
Bits [31:16] = 0
Bits [15:6]  = Base Pointer (from DDMABP — on DSDMA.exe, this plays the role of whatever
               I/O base SETUPDS/ds.ini assigned the YMF724's D-DMA slave block)
Bits [5:4]   = channel number: 0→00, 1 or 5→01, 2 or 6→10, 3 or 7→11
Bits [3:0]   = register offset (see table below) — NOTE: not the same layout as the 8237 itself
```

## 8237 legacy register → DDMA peripheral offset (Table 25, transcribed)

| Legacy 8237 port (DMA1 / DMA2) | R/W | 8237 register | Peripheral offset |
|---|---|---|---|
| `0,2,4,6h` / `C4,C8,CCh` | W | Base Address A[0:7] | `Base + chan + 0h` |
| `0,2,4,6h` / `C4,C8,CCh` | R | Current Address A[0:7] | `Base + chan + 0h` |
| `0,2,4,6h` / `C4,C8,CCh` | W | Base Address A[8:15] | `Base + chan + 1h` |
| `0,2,4,6h` / `C4,C8,CCh` | R | Current Address A[8:15] | `Base + chan + 1h` |
| `87,83,81,82h` / `8B,89,8Ah` | R/W | Page Register | `Base + chan + 2h` |
| `1,3,5,7h` / `C6,CA,CEh` | W | Base Word Count D[0:7] | `Base + chan + 4h` |
| `1,3,5,7h` / `C6,CA,CEh` | R | Current Word Count D[0:7] | `Base + chan + 4h` |
| `1,3,5,7h` / `C6,CA,CEh` | W | Base Word Count D[8:15] | `Base + chan + 5h` |
| `1,3,5,7h` / `C6,CA,CEh` | R | Current Word Count D[8:15] | `Base + chan + 5h` |
| `08h` / `D0h` | W | Command Register | `Base + chan + 8h` |
| `08h` / `D0h` | R | Status Register | `Base + chan + 8h` |
| `09h` / `D2h` | W | Request Register | `Base + chan + 9h` |
| `0Bh` / `D6h` | W | Mode Register | `Base + chan + Bh` |
| `0Dh` / `DAh` | W | **Master Clear** | **`Base + chan + Dh`** |
| `0Ah` / `D4h` | W | Single Channel Mask | — |
| `0Eh` / ... | W | Write All Masks | `Base + chan + Fh` |

(Single Channel Mask and Clear Mask Command have no distinct peripheral register — PIIX4
folds both into a Write-All-Masks write on the peripheral's behalf. A software master
reimplementing this doesn't need to special-case them either.)

## Why this matters for the open question

The earlier notes' leading theory for `DSDMA.exe`'s "first real DMA use after load is unreliable"
bug (the Doom demo-end hang, fixed by running Duke Nukem 3D first) is a missing **Master
Clear** (`Base + chan + Dh`) during TSR init. This table confirms Master Clear is a real,
distinct, write-only register in the protocol — not folded into anything else — so its
absence from `DSDMA.exe`'s init path would be a genuine, checkable omission, not a
misreading of the spec. This is the first thing to check once the TSR's init routine is
located in the disassembly.
