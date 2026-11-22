# 0. Scope and terms

## 0.1 Purpose

This is a specification for a replacement of the **card setup tool**: the DOS program that brings a Yamaha YMF724-family sound card from its power-on state to a working Sound Blaster-compatible state, and that decides whether a separate DMA master program has to be loaded afterwards. In the vendor's package it is `setupds.exe`.

It describes one mode of the original: the **silent apply** mode (the `/s` command-line switch), on one card: a **YMF724F** with the vendor's stock settings. A replacement that does this and leaves the card in the state described here can be used in place of the original, with the vendor's DMA master program or with a replacement for it (see the `interaction/` specification).

## 0.2 What is covered, and what is not

Covered:
- the silent apply path, in the order the original performs it;
- the PCI configuration, memory-mapped register and codec writes it makes;
- the self-test and the exit code (the exit code is defined in the `interaction/` specification);
- the state it leaves the card in.

**Not covered.** These parts of the original have not been captured, and a replacement cannot be built from this specification for them:
- the **interactive mode** (no switch): its menus, volume screens and sound test. It was not traced;
- cards other than a YMF724F. The original has branches for other family members (YMF744, YMF754 and the revisions with extra I/O-base registers). They were read but never run, and are described only where they affect what the YMF724F path does not do;
- the programming of **host chipsets that already provide distributed DMA or PC/PCI DMA**. The original recognises a list of chipsets and programs them; on any other chipset it takes the path described here. Which chipsets it recognises is listed in section 4.2 as an open question, not specified;
- a secondary AC'97 codec;
- the other programs in the vendor's package: a program that reports the card's interrupt, and a media-player demo used by the interactive sound test.

## 0.3 Terms

- **Card**: a YMF724F, PCI vendor 1073h, device 000Dh, revision 03h.
- **Settings**: user-selectable values the tool takes from a settings file (the `interaction/` specification defines the file's grammar). Where this specification says "stock settings" it means the values listed in that specification as the vendor's defaults.
- **Unrecognised chipset**: a host chipset not on the original's built-in list. The Intel 8-series and 9-series chipsets are not on it.
- **BAR0**: the card's 32 KB memory-mapped register window, PCI configuration offset 10h.
- **Original**: the vendor's `setupds.exe`, as shipped in the YMF744 DOS driver package.
- Register names follow the YMF724F datasheet where it defines them, otherwise the Linux `ymfpci` driver's names. Hex numbers use an `h` suffix.

## 0.4 Requirement format

As in the top-level README. Identifiers use the prefix `SDS-`; open decisions use `SDEC-`; acceptance checks use `STEST-`.
