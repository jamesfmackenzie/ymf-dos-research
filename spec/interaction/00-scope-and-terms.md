# 0. Scope and terms

## 0.1 Purpose

Two vendor programs bring a Yamaha YMF724-family card up for DOS on a machine whose chipset has no distributed DMA of its own:

- the **card setup tool** (`setupds.exe`): configures the card, runs a self-test and exits with a code that says whether the second program is needed;
- the **DMA master TSR** (`Dsdma.exe`): a resident program that switches the card to distributed DMA and redirects the PC's DMA port accesses to it.

A boot batch file (`LOADTSR.BAT`) runs the first and, on exit code 2, the second.

This specification defines **how the two interact**: who owns which part of the card's state, what state exists at the hand-over, what the exit codes mean, and the grammar of the settings file the setup tool reads. It is the contract that lets either program be replaced independently: a new setup tool that honours it works with the vendor's TSR or a new one, and the other way round. Two other specifications each define one side; this one defines the boundary and refers to neither of them.

## 0.2 Not covered

- The interactive mode of the setup tool.
- Chipsets the setup tool recognises and programs itself; on those it exits 0 and no TSR is needed. Only the unrecognised-chipset path is specified.
- How a TSR gets its settings other than the defaults (a decision, `IDEC-1`).

## 0.3 Terms

- **Setup tool**, **TSR**, **boot batch file**: as above.
- **Hand-over**: the moment the setup tool exits and the TSR starts.
- **Unrecognised chipset**: a host chipset not on the setup tool's built-in list (the Intel 8 and 9 series are not).
- **Settings file**: a text file the setup tool reads; see chapter 2. The file's name and location are not part of this specification.

## 0.4 Requirement format

As in the top-level README. Identifiers use the prefix `INT-`; decisions `IDEC-`; checks `ITEST-`.
