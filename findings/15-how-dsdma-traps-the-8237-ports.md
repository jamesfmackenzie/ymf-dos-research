# Finding 15 — How `Dsdma.exe` traps the 8237 ports (VCPI host hook, IOPM + #GP)

**Date**: 2026-10-09
**Basis**: ndisasm of `Dsdma.exe` (code only, MZ header stripped), addresses are segment-0x59
IPs (`ndisasm -e 0x590`; PM code selector 0x20 has base = linear of seg 0x59, so IP = PM
offset). Short excerpts in `findings/excerpts/`; the full listing is regenerated with `tools/regen-listings.sh` (see `docs/reproducing.md`). Jemm source read from a local checkout
(a local Jemm source checkout, git `e96bb6b`, 2026-05-26), not from a spec.
Tags: **(verified)** = read directly in the disassembly/source; **(inferred)** = reasoning,
not traced or not run. Ghidra cross-check not done for this finding (ndisasm only).

## Short answer

`Dsdma.exe` is **not** a stand-alone V86 monitor and does **not** use a port-trap API from the
memory manager. It *borrows the memory manager's protected-mode environment through VCPI* and
patches it from inside:

1. It reads the VCPI server's own host state (CR3, GDTR, IDTR, TSS) via `INT 67h DE0Ch`
   and by `SGDT/SIDT/STR` once in PM (verified).
2. It sets bits in the **host TSS I/O permission bitmap** (IOPM) for the legacy DMA ports, so
   V86 `IN/OUT` to them raise #GP instead of reaching hardware (verified).
3. It **patches the host IDT's vector 13 (#GP) gate in place** to point at its own code
   (`0x1020`), which decodes the faulting instruction, emulates the 8237 in software and
   redirects the effects to the D-DMA slave block (verified).
4. It also hooks other vectors in the host IDT via per-vector stubs (verified); resume is
   a normal return from the exception into the server's V86 monitor path (inferred, see Q3).

Net effect: a **hypervisor-lite stacked on the VCPI server** (EMM386/Jemm/QEMM), sharing its
page tables and TSS. That is why it needs VCPI at all.

## Q1 — What happens after `DE0Ch`? (verified unless noted)

- `0xC6FF` (enter-PM): `cli`, `mov eax,0xDE0C`, `int 67h` with `ESI` -> a state structure
  (CR3, GDTR/IDTR linear, LDTR, TR, EIP, CS). On arrival at `0xC71C` it loads
  `DS=ES=GS=SS=0x28`, `FS=0x30`, restores SP from `[CA6A]`, and sets `[78BC]=2`.
- `0xC743` (return-to-V86): builds the 9-dword frame (`GS FS DS ES SS ESP EFLAGS CS EIP`,
  segments = 0x59) and far-calls the VCPI PM entry (`[78A4]`) with `EAX=DE0Ch`; sets
  `[78BC]=3` before the final return in the init tail.
- The bootstrap environment (`0xC3D3`–`0xC760`) is DSDMA's **own temporary GDT/IDT/TSS**,
  built by `0xB8B4`–`0xBFD9` just to survive the first PM entry. During it DSDMA reads
  the **host** descriptors: `0x171B` reads the host TSS descriptor into `[78AA]`
  (base) / `[78AE]` (limit); host CR3 saved in `[8012]`; host GDT `[7894]/[7896]`,
  host IDT `[789A]/[789C]`; own code selector added to the host GDT `[7884]`; flat selector
  `[7888]`.
- Mode flag `[78BC]`: 1 = V86, 2 = PM via DE0C (bootstrap), 3 = running on the **host**
  tables. Every table-touching helper tests `[78BC]==3` and picks `[7888]` (flat) instead
  of `0x30` (e.g. `0x17F6`, `0x67C0`).
- Final init tail (`0xC010`–`0xC240`): `0x63C2(3)`, `0x63C2(4)` (hook phases),
  `[78BC]=3`, `0xC743`, `0x63C2(5)`, then `INT 21h AX=3100h` (TSR).
- **GDT/IDT/TSS summary**: after init the live tables are the VCPI server's (host) tables
  with DSDMA additions: one code descriptor, and in-place edits to the IDT gates and
  TSS IOPM. The bootstrap tables are not used afterwards (inferred from `[78BC]=3`
  gating; the second environment built at `0xAC46`–`0xB3DE` is not fully explained, see
  Open).

## Q2 — Which ports are trapped? (verified: registration table, `0xA853`–`0xAB5D`)

Registration is `0x17DF(port, handler)`: it refuses ports >= 0x600, writes the handler
offset into a per-port table at `[7440]` (word per port), and sets the port's bit in the
host IOPM (`0x1782`, with a shadow bitmap so removal restores the previous state).

| Ports | Handler | What |
|---|---|---|
| `00,02,04,06` / `01,03,05,07` ... (even=address, odd=count) | `0x6E7` / `0x785` | 8237 #1 channel addr / count |
| `C0,C4,C8,CC` / `C2,C6,CA,CE` | `0x6E7` / `0x785` | 8237 #2 (ch4-7) addr / count |
| `08–0F`, `D0–DE` even | `0x601`, `0x823`, `0x83C`, `0x873`, `0x8A1`, `0x8BD`, `0x93E`, `0x998`, `0xA02`, `0xA72` | status/cmd, request, mask, mode, flip-flop clear, master clear, mask-all |
| **page regs `81 82 83 87 89 8A 8B`** | page handlers | **Yes, page registers are trapped** (but not `80`, `84–86`, `88`, `8C–8F`) |
| `20 21 A0 A1` | pass-through `0xD5` | PIC ports (registered so DSDMA sees IRQ mask/EOI changes; handler passes to hardware) |

Page ports trapped are exactly the 8237 channel page registers: 87=ch0, 83=ch1, 81=ch2,
82=ch3, 8B=ch5, 89=ch6, 8A=ch7 (standard PC map). `0x80` (POST/delay) and `0x8F` (ch4
page) are deliberately **not** trapped, same choice Jemm itself made in v5.84
(`JEMM32.ASM:273`).

Trapping is **per bit**, so only registered ports fault. All other I/O runs at full speed
(verified for the mechanism; the exact set of unlisted ports not exhaustively enumerated).

**Only one channel is actually emulated.** The per-channel structs at `0x71E2` (ch0-3) and
`0x7262` (ch4-7) are all populated, but hooked channel `[7178]` defaults to **1**. Ports of
other channels fault into the same handlers, which then **pass the access through to the
real 8237** (verified from the channel-resolver at `0x530`–`0x5FF`; the hooked-vs-not
branch reads the channel's callback table). Pass-through still costs a #GP per access
(inferred: nothing in the code unsets the IOPM bit for non-hooked channels).

## Q3 — The #GP handler (verified)

`0x1020` is installed as the host IDT vector 13 gate (`0x66A1` / `0x6446` patch the
gate; saved original at `0x7A02`, 6 bytes per vector). It does:

> **Correction (Finding 16, dynamic, 2026-10-10)**: the gate points at Dsdma's stub `0048:68B4` (`call 0x6C80`), not at 0x1020; 0x6C80 dispatches via the table at `[0x78C0]` to 0x1020. #PF (vector 14) is also hooked (`0048:68B8`). Jemm already traps the page regs and most of 00-0F/C0-DE; Dsdma adds only 08/09, 20/21, A0/A1, C0, C2, D0, D2. Saved gates for 13/14 observed at F7C07A52. See `16-dosbox-x-dynamic-verification.md`.


1. `0x1D4A(frame)` -> locate the faulting `CS:EIP` (test `[frame+0x34] & 0x20000` = VM
   flag; V86 uses `seg*16+IP` via `0x1CBE`, PM uses the descriptor base via `0x1C30`).
2. `0x1666` prefix decoder: consumes `66` (operand size), `67` (address size), `F2/F3`
   (REP), segment overrides; returns the opcode pointer and prefix flags (`EDX`).
3. Dispatch `call word [bx+0x744E]` where `bx = 2*opcode`. Entries (verified, dumped to
   `excerpts/gp-opcode-table-744E.txt`):

   | Opcode | Handler | Meaning |
   |---|---|---|
   | `6C 6D 6E 6F` | `1148 11C0 124B 12C1` | INSB / INSW/D / OUTSB / OUTSW/D |
   | `E4 E5 E6 E7` | `13B3 134A 1463 13FA` | IN/OUT imm8 |
   | `EC ED EE EF` | `150B 14AA 15AB 154A` | IN/OUT DX |
   | `FA FB` | `1619 15EA` | CLI / STI (IOPL<3 emulation) |
   | `0F` | `109A` | CRn/DRn moves (so a V86 or PM client touching CR is emulated) |
   | all others | `1060` | returns 0 = "not handled" |

4. Each I/O handler resolves the port through the `[7440]` table, calls the registered
   port handler (`CALL BX`/`CALL word [BX+0x18]`), and splits word/dword/string accesses
   into byte accesses (splitter at `0x1934`, **read** only partially; **inferred** to be a
   loop of byte calls with the REP count taken from `CX/ECX` according to the
   `66/67` flags).
5. Return value 0 -> the stub returns "unhandled" and the original chain (the server's
   own #GP handler) runs. Non-zero -> consumed (inferred from the `0x1060`/`0x1068`
   lookup returning 0).

**Resume (inferred, partially verified).** The handler advances the saved `EIP` by the
decoded instruction length (including prefixes) in the exception frame, then `ret`s to
the common stub, which restores the saved registers and executes the server's return to
V86 path (`iretd` at the end of the `0x2611`–`0x28D2` epilogue: there the frame is
rebuilt with `and bx,0xFCFF` clearing TF/IF in the copied EFLAGS, which is VM86-aware code
shared with the INT-reflection path). I did not step through a complete fault -> resume
cycle, so "resumes via the server's own IRET" is inference.

## Q4 — Own monitor, or memory-manager API? (verified)

Neither of the two clean options; it is a **third thing**:

- It is **not** a full V86 monitor of its own (verified): no GDT/TSS of its own survives
  init (`[78BC]=3`), no INT n reflection for V86 clients of its own, no page-table
  construction for V86 (it calls `DE04` to allocate pages and writes PTEs via `0x681A`
  only for its own buffers).
- It is **not** using a trap API (verified): there is no *call* of `INT 2Fh AX=1684h BX=4354h` (QPI)
  or `INT 2Fh 1687h`, no Jemm JLM import. (**Correction, Finding 19**: it *answers* `INT 2Fh
  AX=1687h` itself via its hook at `0x3432`, i.e. it is a DPMI 0.90 host, and answers `INT 67h
  DE00h` with AH=84h to hide VCPI from later clients.) The only INT 2Fh in the code is the `0xC254`
  probe for a `'KESB'` signature (`AX=C000h` -> `AL=FFh`, `BX=454Bh`, `DX=4253h`, i.e.
  "KE","SB"), which returns four far entry points stored at `[8448..845C]` and
  calls them from the vector stub for vectors 1–3 and `[78B2]+1`. This looks like a
  debug/monitoring hook of Yamaha's own dev tools (**inferred**); gated by `[847D]`, which
  stays 0 unless that signature answers.
- It **edits the VCPI server's tables in place** (IDT gate, TSS IOPM). That is why it
  needs VCPI (to get CR3/GDT/IDT/TSS addresses and a way into PM) and why it is stacked
  *on* EMM386/Jemm/QEMM, not beside it. Evidence: `0x6446` IDT gate patcher, `0x1782`
  IOPM setter with shadow, `0x171B` host TSS read, host IDT/GDT/TSS pointers in
  `[789A]/[7894]/[78AA]`.

## Q5 — From trapped writes to D-DMA registers (verified, reg offsets per Findings 4/5)

- Each emulated channel struct holds a software 8237 view: base/current address, count,
  mode, mask bit, request bit, flip-flop state (shared flip-flops at `0x71E0/0x71E1`),
  and a callback table copied from `0xC7B0` to struct+0xE by `0xAC7`.
- Address/count writes go through the two flip-flop handlers `0x6E7`/`0x785`: low byte then
  high byte, flip-flop toggling per controller. A page-register write stores the byte
  into the channel's page field. **24-bit address = (page << 16) | (hi<<8 | lo)** for
  ch0-3; for ch5-7 the 8237 #2 semantic (word addresses, shifted by one) is applied
  (the shift is verified in the count/address handlers; the exact ch4-7 rounding
  rules were not exhaustively read - inferred equivalent to the standard PC map).
- Flush (`0x601`) / unmask / mode writes translate to the D-DMA slave registers through
  the callback table accessors at IP `0x01, 0x26, 0x36, 0x56, 0x64, 0x7A, 0x8D, 0x9F,
  0xB1` (the offsets set in Finding 4: {2,4,5,8,0xb,0xe,0xf,0xc0,0xffff}) against slave
  base `[7174]` = 0xF390. This answers Finding 5's "dispatch table" question: the
  `CALL word [BX+0x18]` sites **are** the callback-table dispatch (table at `0xC7B0`),
  they are not a per-opcode table.
- Master Clear (+0Dh) and Request (+09h) are still never issued (Finding 5 stands): the
  emulated "master clear" (port 0x0D/0xDA) handler resets only the software state
  (verified in `0x8BD`/`0x93E`).

## Q6 — A20, extended memory, page tables

- **A20: no handling at all** (verified by search): no `OUT 92h`, no `0x60/0x64`
  keyboard-controller commands, no `INT 15h AH=24h`, no XMS calls. The A20 line is the
  VCPI server's responsibility; DSDMA assumes it is on whenever it is in PM (inferred
  from absence). Note this is where Jemm's own `A20_Handle60/64/92` traps (Jemm
  `JEMM32.ASM:290`) matter if someone ever runs with `A20METHOD`/NOA20.
- **Extended memory**: allocates with VCPI `DE04` (`0x67DF`, returns page physical
  address & 0xF000 mask) and writes PTEs at `0x681A`; uses VCPI `DE02` max address;
  hooked tables sit in that memory (verified).
- **Page-table state at mode switches**: host CR3 saved in `[8012]` and passed back in
  the DE0C state struct; DSDMA never builds its own page directory (verified: no
  `mov cr3` except in the `0x109A` emulation path and the DE0C state).
- **Cost**: each fault = V86 -> server #GP -> DSDMA -> return, plus D-DMA slave
  register access (`IN/OUT` on a PCI port). Fine for DMA programming; not for a
  per-byte path (inferred).

## Corrections to earlier findings

- **Finding 3** — "Caveat, not yet traced" is now traced: see this finding. **Finding 19
  retracts the "VCPI independent of DPMI host / extender-agnostic" point**: VCPI clients are not
  trapped; Dsdma hides VCPI and acts as the DPMI host. In addition the trap is IOPM + #GP in
  the *server's* tables, so it is coupled to the specific VCPI server's TSS/IDT layout.
- **Finding 13** Stage B — "Hooks VCPI; services chipset-style trapped 8237 accesses in
  software" refined: hooks the VCPI **host's** IDT vector 13 and TSS IOPM.
- **Finding 5** — the open "dispatch table" paragraph is answered above (Q5).

## Open (not traced)

- Who runs the DOS session after init: the host environment is by far most likely
  (`[78BC]=3`), but a **second DSDMA-built PM environment at `0xAC46`–`0xB3DE`** is
  built and not explained. **inferred**: a fallback for servers that don't expose a
  usable TSS (e.g. QEMM in stealth mode).
- The `0x1934` splitter, rest of `0x2611`–`0x28D2` (note: `dr3`/`dr7` programming at
  `0x27ED`–`0x27FF` sets a data breakpoint (DR7=…0x280), purpose unknown), the 'KESB'
  hook.
- Whether the access goes **before or after** Jemm's own DMA-port trapping (Jemm
  traps `00–0F`, `81–8B`, `C4–DF` for its VDMA buffering, `JEMM32.ASM:285–287`). In
  principle DSDMA's in-place IDT patch runs first (inferred).
- No run on real hardware or in DOSBox-X was done for this finding.

## Can this be done without VCPI?

What the generalized TSR actually needs: (1) a place where V86 `IN/OUT` to `00–0F`,
`81–8B`, `C0–DF` faults; (2) a way to run code at ring 0 on fault; (3) to resume the
client.

**(a) Own V86 monitor on HIMEM only.** Feasible, ~2–3 kLOC. Needs: own GDT/IDT/TSS+IOPM,
page tables with the identity map, the V86 IRET entry, #GP emulation (the opcode
table above is a good template), full INT reflection (hardware IRQs, INT n, `STI/CLI`,
`PUSHF`, `IRET` under IOPL<3), A20 control, and the memory manager must not also be
present (EMM386/Jemm can't coexist). Gives full control but loses EMS/XMS-UMB services
that games rely on, so it has to *provide* them. **Cost: highest; and reinvents what Jemm
already is.**

**(b) Port-trap interface provided by Jemm386.** **Yes, one exists, but not in Jemm
itself**: two Jemm "JLM" modules ship in the source tree (verified, local):

- `JLM/QPIEMU` — emulates the I/O-trapping subset of **Qemm's QPI**: `INT 2Fh AX=1684h
  BX=4354h` -> ES:DI = entry; then `AX=1A09h/1A0Ah` trap/untrap port `DX`, `1A07h/1A06h`
  set/get a real-mode far **callback** (called with `CL`: bit2 OUT, bits3-4 size,
  `CH` bit1 = IF, `DX` = port, `AL/AX/EAX` = data), `1A00/01/04` untrapped I/O to bypass
  your own trap. Call is done in real mode, handler runs in V86 via nested exec (so no PM
  code needed). Verified from `QPIEMU.ASM:56–225`, doc `QPIEMU.txt`.
- `JLM/IOTRAP` — raw `Install_IO_Handler` (VMM service), 32-bit JLM only, byte
  ports only, documented as superseded by QPIEMU.
- Limits: needs `JLOAD` + `QPIEMU.DLL` before the TSR; **string/REP port I/O is not
  decoded for you via QPI** (the callback sees `CL` flags; handling of REP is in Jemm's
  IO dispatcher - not verified), and **Jemm already traps the DMA ports for its own
  VDMA** (`?DMAPT`, `VDMA.ASM`): an `Install_IO_Handler` on those ports may collide
  with the built-in table (`IO_Trap_Table`, "may be modified by JLOAD") (**inferred**,
  must be tested). EMM386 and QEMM have no equivalent public API. QEMM has the real QPI
  (which QPIEMU copies); EMM386 has none.
- This is also what **SBEMU** uses for exactly this purpose.

**(c) What the trace suggests: copy DSDMA's pattern.** Use VCPI only to *find*
the server's CR3/GDT/IDT/TSS and enter PM, then (1) set IOPM bits, (2) chain the #GP
gate, (3) decode `IN/OUT/INS/OUTS` + REP + prefixes (opcode set above is the complete
list), (4) return unhandled to the server for everything else. It proves the technique
works across EMM386/Jemm/QEMM VCPI servers (Yamaha shipped it) with **no JLM
dependency**. Fragilities: coupling to the server's TSS/IOPM layout, the Jemm/EMM386 DMA
ports trapped twice, no A20 handling. Also costs: `#GP` per access even for
non-hooked channels.

**Recommendation for the generalized TSR.**

1. **Primary: (c)**, VCPI + IDT/IOPM hook, because it is the only approach already
   verified to work on shipping Yamaha hardware setups and needs only the memory manager
   plus VCPI that DOS games already need. Reuse DSDMA's opcode table design, a
   per-channel struct, and the callback table for chipset back-ends.
2. **Second: borrow SBEMU's DMA/port-trap layer (b), leave its emulation behind.** SBEMU
   already solves port trapping on top of QPI (QPIEMU on Jemm, real QPI on QEMM; QPIEMU.txt
   names SBEMU as its client) and has its own 8237/page-register handling. Take only that:
   the trap registration, the DMA-port decode and the channel address/count/mask state.
   Drop the SB DSP, OPL/FM, mixer, resampling and audio-output code, since the YMF724 does
   the real audio. The D-DMA slave back-end (Finding 5 register sequence, plus Master Clear)
   replaces SBEMU's software-audio sink. Benefits: no ring-0 code, a maintained code base,
   and Jemm's author supports the QPI route. **Not yet checked**: I have not read the SBEMU
   source, so what is separable, its licence, and how it handles REP/string I/O and the
   Jemm DMA-port overlap are all unknown. That review is the next step.
3. **Skip (a)** unless both fail; it duplicates Jemm.
4. Add what DSDMA lacks: trap only the **chosen** channel's ports (DSDMA sets bits for all
   and passes the rest through), explicit Master Clear on the slave (Finding 5), and test
   under Jemm's own DMA trapping before trusting.

Not tested: none of the above has been run; (b)'s collision with Jemm's DMA table is the
first thing to check.

**Update (Finding 17)**: the collision was tested: QPIEMU can take over every Jemm-trapped DMA
port (verified), except channel 2's mask/mode writes (Jemm pre-empts them). Recommendation 2
stands with two caveats: REP string I/O arrives as a single callback with no count (so it
cannot be implemented), and a callback must merge IN results into EAX itself.

## Key excerpts
Short slices of the disassembly the above relies on (IP-basis addresses):
- [`excerpts/gp-handler-dispatch-1020.txt`](excerpts/gp-handler-dispatch-1020.txt) — the #GP handler at 0x1020
- [`excerpts/gp-opcode-table-744E.txt`](excerpts/gp-opcode-table-744E.txt) — opcode-to-handler table
- [`excerpts/idt-stub-common-entry-6C80.txt`](excerpts/idt-stub-common-entry-6C80.txt) — common entry from the IDT stubs
- [`excerpts/kesb-int2f-C254.txt`](excerpts/kesb-int2f-C254.txt) — the INT 2Fh 'KESB' hook

Longer ranges are listed by start address in `docs/reproducing.md`.
