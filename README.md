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

## Origins & EhBASIC

This version of EhBASIC is **derived from EhBASIC**, developed by Lee Davidson. The EhBASIC license allows for non-commerical use only. The most recent release and manual is hosted [here](https://github.com/Klaus2m5/6502_EhBASIC_V2.22), and a mirror of Lee's website can be found [here](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/).

> EhBASIC is free but not copyright free. For non commercial use there is only one restriction, any derivative work should include, in any binary image distributed, the string "Derived from EhBASIC" and in any distribution that includes human readable files a file that includes the above string in a human readable form (e.g., not as a comment in an HTML file).
