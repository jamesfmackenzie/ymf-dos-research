# 4. Open questions and decisions

## 4.1 Decisions

- **IDEC-1** - *How user choices reach the TSR.* The original loses them (`INT-12`). Options: keep the compiled-in defaults; give the TSR a command line; have the TSR read what the setup tool left in the card's configuration; or have the TSR read the settings file. *Considerations:* the first reproduces the original and costs nothing; a command line is simple but makes the user repeat choices; reading the card needs the fields to be reliably readable once the card is configured; sharing the file couples the TSR to the file's grammar (chapter 2) and its location, which is not specified. The same question applies to a replacement setup tool: it may keep the grammar of chapter 2, extend it, or replace it.

## 4.2 Things nobody knows yet

- **Whether the setup tool's self-test leaves the Sound Blaster DSP in an unfinished state** when its DMA check fails. On an unrecognised chipset the card is in the reserved DMA mode while the check runs, so the check can only fail after the DSP has been given a DMA command. If the DSP is left mid-command, the first real transfer after the TSR loads would begin from that state. Not measured. A way to tell: reset the DSP after the TSR has loaded and see whether a symptom seen in the original goes away.
- **What the level-triggered interrupt setting does on a modern chipset.** The setup tool makes the card's interrupt level-triggered and the TSR never changes it. Whether level or edge is the better setting on a machine whose interrupt controller was not designed for this card has not been measured.
- **The location of the settings file** and how the setup tool finds it (the current directory, its own directory, or the path it was started from).
- **Whether line order, case, extra spaces, comments or blank lines matter** in the settings file (`INT-16`).
- **The radix of the selector keys** (`INT-17`).
- **The meaning of** `FIRSTTRY`, `IRQSHARE`, `PIRQRC`, `DEBUG` and `REPEAT`.
- **The exit code on a recognised chipset** (`INT-10`), and what the setup tool does there.
- **Whether running the interactive sound test after the TSR is loaded** succeeds where the silent apply's test failed. This would need the setup tool to be started with the TSR resident.
