# 4. Open questions and decisions

## 4.1 Decisions an implementer must make

These are choices the evidence does not settle. The specification takes no side.

- **SDEC-1** - *Microcode.* The original always downloads the vendor's microcode and starts the native engine, then stops it again before exiting. The images are not included here and their redistribution terms are not known. Whether legacy Sound Blaster operation needs them has not been tested in the recorded sessions. *Considerations:* omitting the download makes the tool independent of the vendor's data and shorter, but removes a step the original performs on every run; including it needs a source for the images that the implementer is entitled to use. `SDS-13`, `SDS-14` and `SDS-15` are written so either choice conforms.
- **SDEC-2** - *The self-test.* The original always runs it. On an unrecognised chipset its DMA check can only fail and does not change the exit code (`SDS-26`). *Considerations:* keeping it reproduces the original's message output and its side effects on the Sound Blaster DSP (a DMA command is issued and not completed); dropping it removes those side effects and a source of unfinished DSP state, but also the check of the DSP reset and interrupt, which do affect the exit code. The side effects are of interest to the `interaction/` specification.
- **SDEC-3** - *Where the settings come from.* See `interaction/` (`IDEC-1`).
- **SDEC-4** - *The BAR0 base when unassigned.* `SDS-3` says to assign one but not which address. *Considerations:* the original's choice was not recorded; on the reference machine the BIOS had already assigned BAR0, so the path has not run on hardware.

## 4.2 Things nobody knows yet

- **The interactive mode.** Menus, volume screens and the sound test were not traced. The sound test is expected to play audio through the Sound Blaster block and the FM synthesiser using a media-player program from the vendor's package.
- **Other family members.** The YMF744 and YMF754, and the device revisions that have extra I/O-base registers (offsets 60h to 66h), were read but not run. Which stored identification value gates them (`SDS-9`) is inferred.
- **The host chipsets the original recognises.** It matches the chipset's PCI device ID against a built-in list of seven device IDs (7100h, 7180h, 7190h, 1543h, 0596h, 0008h and 2420h). What it does for each is not specified here.
- **Which settings key selects the "fill both interrupt fields with 7" branch** (`SDS-18`). The interrupt-mode setting is the obvious candidate.
- **The microcode's destination offsets** inside BAR0 (1000h and 4000h in an earlier reading) were not re-checked.
- **The interrupt scan** (`SDS-7`): its purpose.
- **The probing behind the status report** (`SDS-27`).
- **The silent-apply branch.** Which settings flag selects it inside the program is inferred from the exit codes it produces, not read directly.
- **What `SMOD = 3` does on the card.** The datasheet marks it reserved and defines no behaviour.
