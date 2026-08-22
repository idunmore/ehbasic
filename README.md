# EhBASIC for the Ben Eater 6502

[![Static Badge](https://img.shields.io/badge/EhBASIC-v2.22p5.7-orange)](https://github.com/Klaus2m5/6502_EhBASIC_V2.22)&nbsp;
[![Static Badge](https://img.shields.io/badge/architecture-Ben_Eater_6502-green)](https://eater.net/6502)&nbsp;
[![Static Badge](https://img.shields.io/badge/assembler-ca65-red)](https://cc65.github.io/doc/ca65.html)&nbsp;
[![Static Badge](https://img.shields.io/badge/CPU-65C02-blue)](https://westerndesigncenter.com/wdc/documentation/w65c02s.pdf)

The goal here is simple:

A full version of [EhBASIC](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/enhanced-6502-basic/) that can be built from source, generate a proper ROM image, and then "burned" to EEPROM and run 100% as-is on a 100% stock Ben Eater 6502 (herein "BE6502") build.

### Motivation: The "Why?"
I've found several **binary** builds (ROM images) of EhBASIC that will run, as-is, on a stock build of Ben Eater's 6502 breadboard computer.

However ...

 - **None** of those that I can find exist in a state where they *also* include the required source, configuration and make/build files necessary to build the project from source.  A couple of them have `make` files and source, but that source *doesn't* build to a BE6502-compatible binary/ROM image.

    This makes it very difficult, if not impossible, to extend or modify the code to support new hardware or keywords.

And ..

- **None** of those I can find implement any kind of interrupt-driven serial input, with buffering and flow-control, and rely on software delays and terminal pacing for handling keyboard input.

    This makes loading large programs via the common copy/paste technique glacially slow, and sometimes unreliable (pacing needs change with the length of the program).

So ... if have a "standard" version that I can build from source I can a) extend it and b) add proper flow-control and input buffering.

Hence ... the point, and goal, of this project.

### Starting Point
The initial code-commit is a full builds-from-source version of EhBASIC that emits a `basic.bin` file that be burned to ROM on a standard BE6502 and "just work", albeit needing terminal pacing (0.6s line, and 0.02s character pacing seems safe, if very slow, for larger programs; smaller programs can use lower values).

*Most of the work, here, was already done by others (the principal source is from [Klaus2m5](https://github.com/Klaus2m5/6502_EhBASIC_V2.22)); all I've done is bring the appropriate parts together in one place, made a few adjustments/tweaks, tidied up some config and the build process for ca65.*

#### v. Next (is now v. Current)

My original intention was that the next step in the project, barring any clean-up, wass to implement serial flow-control and input buffering for BE6502 builds that have that enabled in hardware.

**This is now done.**

Thus what was to be "v. Next" is *now* "v. Current".

Note that the flow control is based on Ben's build that fixes the 65C51 UART bug, and requires running a connection from PA0 to CTS.

This update also includes a fix for an interrupt safety issue (see the commit details).

### Additional Enhancements

#### Type-Ahead No Longer Loses Characters

Stock EhBASIC looks for `[CTRL-C]` by reading the input device itself, from
`CTRLC`, which runs after every direct command and between the statements of a
running program. Whatever byte it finds is put in `ccbyte` under a countdown
that only `GET` ever reads, so anything that is not a `[CTRL-C]` is swallowed.
With input buffered, that reliably eats a character whenever anything is typed
or pasted ahead of the prompt: `NEW` followed immediately by `10 PRINT "A"`
would store line **0**.

The `[CTRL-C]` is now spotted by the serial interrupt handler and recorded in a
flag, and `VEC_CC` points at a check that reads that flag instead of the input
stream (`CCHECK` in `min_mon.s`). Nothing is taken out of the input, and
`[CTRL-C]` still breaks a running program even with type-ahead queued up behind
it. A `[CTRL-C]` typed at the `Ready` prompt is discarded once the line it was
typed into is complete, so it does not stop whatever is entered next.

#### True BACKSPACE Support

`BACKSPACE` now visually deletes the character it back-spaces over, rather than leaving it on the display.  This works for all input.

#### WozMon Monitor in ROM

I like having WozMon available on my BE6502 ROMs, particularly those involving BASIC in some form (in addition to this EhBASIC version, I've also built a modified version of [Microsoft BASIC](https://github.com/idunmore/msbasic)).  You can switch back/forth between EhBASIC and WozMon.  Be sure to choose [W]arm start when coming back into EhBASIC if you want to retain the program that was there when you ran `MONITOR`.

## WozMon

The ROM contains [WozMon](https://www.sbprojects.net/projects/apple1/wozmon.php), Steve Wozniak's 256 byte Apple 1 monitor, so you can examine and change memory, and run code, without leaving BASIC behind.

From the `Ready` prompt (or from inside a program):

```
MONITOR
```

WozMon's usual syntax applies: `FE00` examines a location, `FE00.FE1F` dumps a range, `0500: DE AD BE EF` stores bytes, and `<addr>R` runs from an address.

### Getting back

The bottom of the ROM is a jump table, so these addresses stay put no matter how the code around them grows:

| Address | `R` command | Effect |
| --- | --- | --- |
| `$8000` | `8000R` | Sign on, then the `[C]old/[W]arm ?` prompt |
| `$8003` | `8003R` | Force a cold start |
| `$8006` | `8006R` | Force a warm start, no prompt |

Neither `MONITOR` nor WozMon disturbs the BASIC program in memory, so `8000R` followed by `W`, or `8006R` on its own, drops you back at `Ready` with your program still listable and runnable.

### ROM and RAM map

| Range | Contents |
| --- | --- |
| `$8000-$8008` | entry jump table |
| `$8009-$A995` | EhBASIC, the minimal monitor and the custom commands |
| `$FE00-$FEFA` | WozMon |
| `$FFFA-$FFFF` | NMI, RESET and IRQ vectors |
| `$24-$2B` | WozMon zero page, taken from EhBASIC's unused `$13-$5A` |
| `$0280-$02FF` | WozMon line buffer, in the tail of page 2 above `Ibuffe` |

WozMon lives at `$FE00` rather than its native `$FF00` because the vectors at `$FFFA`
leave only 250 bytes there, and this version is slightly larger. It shares `CHRIN` and
`CHROUT` with the rest of the ROM instead of carrying its own copy of the 65C51 transmit
bug workaround, so it gets the same interrupt driven input, flow control and visual
backspace as BASIC does.

### Adding your own commands

`MONITOR` is a *real* EhBASIC keyword, not a `CALL`. Adding another follows the same four
table edits in `basic.s` — a `TK_` equate, a `LAB_CTBL` vector, a keyword table entry
under its first letter, and a `LAB_KEYT` entry for `LIST` to detokenize it — with the
command body itself in `custom_commands.s`.

## Origins & EhBASIC

This version of EhBASIC is **derived from EhBASIC**, developed by Lee Davidson. The EhBASIC license allows for non-commerical use only. The most recent release and manual is hosted [here](https://github.com/Klaus2m5/6502_EhBASIC_V2.22), and a mirror of Lee's website can be found [here](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/).

> EhBASIC is free but not copyright free. For non commercial use there is only one restriction, any derivative work should include, in any binary image distributed, the string "Derived from EhBASIC" and in any distribution that includes human readable files a file that includes the above string in a human readable form (e.g., not as a comment in an HTML file).
