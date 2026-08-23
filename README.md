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

*Most of the work, here, was already done by others (the principal source is from [Klaus Dormann's](https://github.com/Klaus2m5) [patched](https://github.com/Klaus2m5/6502_EhBASIC_V2.22/tree/master/patched) version of ["regular" EhBASIC v2.22](https://github.com/Klaus2m5/6502_EhBASIC_V2.22)); all I've done for the starting point make a few adjustments/tweaks/config changes so it builds and runs cleanly for the stock Ben Eater 6502 board.*

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

## Build Options

None of the debug machinery below is in the ROM unless you build for it. A plain `make` produces the stock image with no trace of it — no code, no cost, and the `POKE` address is inert.

```
make                      the stock ROM
make SENTINEL=n           build the program chain sentinel in, armed at n
                          headers per statement on reset. n=0 builds it in but
                          leaves it disarmed
make DEBUG=1              build the block watch, the 8009R bus stress test and
                          the page zero dump in
make SENTINEL=1 DEBUG=1   both
```

<details>
 
<summary>Build Option & Debug Aid Details</summary>

## Debug Aid Details

`POKE 236,n` still overrides the sentinel at runtime in any build that has it, so the compile-time value is only the (default) setting it comes up with after a reset.

The `$8009` entry-table slot stays put whether or not the bus stress test is built, so `8000R`, `8003R` and `8006R` never move; without `DEBUG=1` it is an alias of `$8000`.

Changing either option rebuilds everything automatically — no `make clean` needed.

Sizes, for reference: the stock ROM ends at `$A9B7`, `SENTINEL=n` adds about 300 bytes, `DEBUG=1` about 240 in `CODE` plus 251 at `$FC00`.

## Program Chain Sentinel (Debug Aid)

There is an outstanding bug where, part way through a long `RUN`, a single byte gets written into the stored program. Every instance so far has landed on the
high byte of a line number in a line header, which throws that line out of order: `LIST <n>` can no longer find it, or anything after it, while a bare `LIST` still walks the chain and shows a line number that could never have been typed. It has not been reproducible under emulation, so the ROM carries a trap for it that runs on a real board.

Build it in with `make SENTINEL=n`, where n is what it comes up with after a reset. The count is also the conditional complitation switch, and `POKE 236,n` overrides it at any time:

```
POKE 236,16     check 16 line headers per statement
POKE 236,0      off again
```

Switched on, EhBASIC's between-statements hook walks that many line headers per statement, picking up where the last statement left off, and checks that every
line number is greater than the one before it and that every link still points inside the program. When one is not, it reports and breaks:

```
*** CHAIN 05E9 E8AE 01A4
0000: 4C 66 81 00 00 00 00 00
0008: 00 00 4C 4E 8F 00 00 00
...
00F8: 00 0B 47 35 DB 5A D7 33
Break in line 5540
Ready
```

The first line reads as: the header at `$05E9` holds line number `$E8AE`, and the line before it was `$01A4`. Then the whole of page zero, in the same shape
the `MONITOR` dumps it.

That dump is taken at the instant the damage is spotted, before anything else runs, and it matters that it is not done by hand afterwards. `$AA/$AB` is
EhBASIC's `Baslnl`, and a single branch reparks it onto the damaged line all by itself — the corrupted line number is out of range, so the next line search
stops there and fails. A dump typed in later cannot tell the pointer that caused the damage from the pointer the damage created.

The `Break in line` names the line that was executing when the damage was *noticed*, which is within one sweep of the line that caused it — a 500 line
program at 16 headers a statement sweeps every ~31 statements. `POKE 236,255` checks the whole chain about every other statement, which puts the break
essentially on the culprit.

The program itself is left completely alone, so `LIST` and `MONITOR` still see it exactly as it was. The one thing the report disturbs is the serial receive
buffer, which it borrows as scratch for the snapshot and then empties, so any type-ahead in flight is lost.

It uses `$E2`, `$E3` and `$E8`-`$ED`, and it re-anchors itself if you edit the program, so it is safe to leave switched on while you type.

### The Block Watch

The chain sentinel is a fairly heavy thing to have running between statements. The block watch is the same idea stripped down: it takes a copy of 128 bytes
when it is armed, then compares four of them per statement, round robin. A whole sweep costs 32 statements and the check itself costs about **5%**, against
+8.4% for `POKE 236,1`.

It watches a block rather than a single byte because this fault lands wherever the stack pointer happens to be. An earlier single-address version sat on
`$05EC` and stayed silent while the very next byte, `$05ED`, was the one being written.

It takes the copy itself, so arming it is three pokes. To watch `$0580`-`$05FF`, which is page five's overlap with the stack addresses EhBASIC actually uses:

```
POKE 236,0      chain sentinel off, the two share zero page
POKE 232,128    block base, low byte
POKE 233,5      block base, high byte
POKE 238,1      arm
POKE 238,0      off again
```

`PEEK(238)` reads 129 once the copy has been taken. The copy lives in WozMon's line buffer at `$0280`, which is free unless WozMon is actually running.
`POKE 232,0 : POKE 233,11` watches `$0B00`-`$0B7F` instead, covering the `$0B5F` case — page eleven being page three's alias one bit over.

When a byte changes it reports the same way the chain sentinel does:

```
*** WATCH 05ED 43 30
0000: 4C 66 81 00 00 00 00 00
...
Break in line 9070
```

The address that changed, the value it held when the watch was armed, and the value found there now, followed by the same page zero dump.

**Note:** Sweeping 128 bytes four at a time means the report can be up to 32 statements behind the write, so the page zero dump no longer
pins the *exact* statement the way a single-address watch did. That immediacy is what identified the mechanism in the first place. The block version is for
coverage, and for telling whether a hardware change actually fixed anything.

Only one of the two can be armed at a time — the watch uses `$E8`-`$EA` and `$ED`, which are the chain sentinel's working bytes, and `$EE` as its own switch.
The watch takes priority: while it is armed the chain walk does not run.

## RAM Bus Stress Test

The line corruption the byte watch caught turned out not to be a software bug at all. The data and the instruction were right; the address was not. Both
addresses it ever damaged are one address bit away from the only two regions of low RAM that anything writes often:

| damaged | intended | bit | what was writing |
|---|---|---|---|
| `$05EC` | `$01EC` | A10 | `LAB_GOSUB` pushing `Bpntrl`, fetched from `$85EE` |
| `$05ED` | `$01ED` | A10 | `LAB_GOSUB` pushing `Bpntrh`, fetched from `$85EB` |
| `$0B5F` | `$035F` | A11 | the serial ISR's `STA INPUT_BUFFER,X`, fetched from `$A9xx` |

**Root Cause: Using a DIP EEPROM "emulator" (picROM).** A real AT28C256 carrying the same image runs the reproducer clean indefinitely; putting the emulator back fails within minutes, with decoupling already improved so it is not supply noise. The emulator loads every line of the shared address bus, and the slower edges (not due to the performance of the picoROM, this appears to be more a function of bread-board construction) mean an address bit has not settled by the time the RAM latches a write address. So develop with it if it is convenient, but burn a real EEPROM to run anything that
matters — and note that a ROM device really can corrupt RAM writes, because they share the address bus.

In every case the bit that went wrong was **high for the instruction fetch and low for the write that followed it**. `$85EB` and `$85EE` both have A10 set;
the push goes to page one, where A10 is clear. The bit does not fall in time and the write lands a kilobyte away. The ISR case is the same story one bit
over.

The values confirm it. `$05ED` was written with `$30`, which is exactly `Bpntrh` for a `GOSUB 7000` in a line living at `$30xx`.

`8009R` from the `MONITOR` runs a test for it, in a `make DEBUG=1` build. It hammers those two pages - the stack, with the read-then-push pattern `GOSUB` uses, and the receive buffer - while holding the whole of the rest of RAM as a guard filled with a pattern computed from the address. Anything that turns up in the guard got there by mistake.

**Where the test's own code lives in the ROM is part of the test.** A stress loop can only exercise the address bits that are high at its own fetch address.
The first version of this routine sat at `$AA93`, where A10 — the very bit that was slipping — is already low, and it ran clean for thousands of passes while a
BASIC program tripped over the fault in minutes. `basic.cfg` now pins it at `$FC00`, where A9 through A15 are all set, so every one of them has to fall on
the way into a page one write. Move it and you change what it can find.

```
BUS TEST - ADDR WAS GOT PASS - RESET TO STOP
..........................
*** BUS 05EC E9 31 001A
....
```

Address, the value that should be there, the value found, and the number of clean passes before it. **The address is the whole story**: exclusive-or it with
`$0400` and with `$0800` and see which result lands in page one or page three. That is the address bit that let go.

It puts the byte back and carries on, so one run collects the whole pattern rather than stopping at the first instance. A pass is about a third of a second,
and it prints a dot for each one.

Interrupts are off throughout, so nothing else can write to RAM and there is no way to type at it — reset the board to stop it, and take the `[C]old` start
afterwards, because it leaves the whole of RAM full of the guard pattern.

It assumes the stock BE6502 map, 16K of RAM at `$0000`-`$3FFF`.

</details>

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
| `$8009` | `8009R` | RAM bus stress test (see above) |

Neither `MONITOR` nor WozMon disturbs the BASIC program in memory, so `8000R` followed by `W`, or `8006R` on its own, drops you back at `Ready` with your program still listable and runnable.

### ROM and RAM map

| Range | Contents |
| --- | --- |
| `$8000-$800B` | entry jump table |
| `$800C-$AC38` | EhBASIC, the minimal monitor and the custom commands |
| `$FC00-$FCFA` | bus stress test, pinned high on purpose |
| `$FE00-$FEFA` | WozMon |
| `$FFFA-$FFFF` | NMI, RESET and IRQ vectors |
| `$24-$2B` | WozMon zero page, taken from EhBASIC's unused `$13-$5A` |
| `$0280-$02FF` | WozMon line buffer, in the tail of page 2 above `Ibuffe` |
| `$0300-$03FF` | serial receive ring buffer, page aligned |
| `$E2-$E3`, `$E8-$ED` | chain sentinel / byte watch / bus test scratch |
| `$EE` | byte watch switch |

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
