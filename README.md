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

## Additional Enhancements

### Type-Ahead No Longer Loses Characters

Stock EhBASIC looks for `[CTRL-C]` by reading the input device itself, from `CTRLC`, which runs after every direct command and between the statements of a
running program. Whatever byte it finds is put in `ccbyte` under a countdown that only `GET` ever reads, so anything that is not a `[CTRL-C]` is swallowed.
With input buffered, that reliably eats a character whenever anything is typed or pasted ahead of the prompt: `NEW` followed immediately by `10 PRINT "A"`
would store line **0**.

The `[CTRL-C]` is now spotted by the serial interrupt handler and recorded in a flag, and `VEC_CC` points at a check that reads that flag instead of the input
stream (`CCHECK` in `min_mon.s`). Nothing is taken out of the input, and `[CTRL-C]` still breaks a running program even with type-ahead queued up behind
it. A `[CTRL-C]` typed at the `Ready` prompt is discarded once the line it was typed into is complete, so it does not stop whatever is entered next.

### True BACKSPACE Support

`BACKSPACE` now visually deletes the character it back-spaces over, rather than leaving it on the display.  This works for all input.

### WozMon Monitor in ROM

I like having WozMon available on my BE6502 ROMs, particularly those involving BASIC in some form (in addition to this EhBASIC version, I've also built a modified version of [Microsoft BASIC](https://github.com/idunmore/msbasic)).  You can switch back/forth between EhBASIC and WozMon.  Be sure to choose [W]arm start when coming back into EhBASIC if you want to retain the program that was there when you ran `MONITOR`.

## LCD Commands

**Note:** The BE6502 build this ROM is written for has an HD44780 character LCD on VIA port B, in 4 bit mode, wired the way Ben Eater's `lcd.s` expects it:

| Port B | LCD |
| --- | --- |
| `PB0-PB3` | `D4-D7`, the 4 bit data nibble |
| `PB4` | `RS`, register select |
| `PB5` | `RW`, read/write |
| `PB6` | `E`, enable |

**A board with no LCD wired to port B would hang at reset**, because `LCDINIT` polls the display's busy flag and a floating input never clears it. That is what `make LCD=0` is for; it leaves the whole thing out, `JSR LCDINIT` included. Everything here assumes the default build with the LCD in.

### The LCD Keywords

Thirteen keywords are provided. They are *real* EhBASIC keywords, not `CALL`s, so they tokenize and `LIST` like anything else. They are ported from the same command set my [Microsoft BASIC](https://github.com/idunmore/msbasic) build for this board carries, so programs move between the two with little more than a retype.

| Command | Argument | What it does |
| --- | --- | --- |
| `LCDCLS` | — | clear the display, which also sends the cursor home |
| `LCDHOME` | — | cursor to the first character of the first line |
| `LCDPRINT` | expression list | print to the display |
| `LCDCURPOS n` | byte | set the DDRAM address, which is where the next character lands |
| `LCDDDRAM n` | byte | the same command under its hardware name |
| `LCDMOVECUR n` | signed | move the cursor right (`n` positive) or left (`n` negative) |
| `LCDSCROLL n` | signed | scroll the display right (`n` positive) or left (`n` negative) |
| `LCDCURENABLE n` | byte | `0` turns the cursor off, anything else turns it on |
| `LCDCURBLINK n` | byte | `0` stops the cursor blinking, anything else starts it |
| `LCDCGRAM n` | byte | point writes at the character generator instead of the screen |
| `LCDCGCHRS` | expression list | write character generator data as characters |
| `LCDCGBYTE n` | byte | write one character generator byte as a number |
| `LCDCMD n` | byte | send a raw HD44780 instruction byte |

<details>

<summary>
LCD Command/Keyword Details
</summary>

### LCD Command/Keyword Details

`LCDPRINT` takes a full `PRINT` style list, so `LCDPRINT "N=";N` works. `;` and `,` are both plain separators — there are no tab stops to move to on a 16 or 20 column display. There is no newline: the display has no scroll, so where the next character goes is `LCDCURPOS`'s business. Numbers are formatted exactly as `PRINT` formats them, which **includes** the *leading space* `PRINT` puts in front of a positive value (important when you are counting columns on a 16 wide display).

```
10 LCDCLS
20 LCDPRINT "TEMP:";T;" C"
30 LCDCURPOS 64 : REM second line
40 LCDPRINT "MAX:";M
```

### Cursor Positions

`LCDCURPOS` takes a DDRAM address, not a row and column, and the second line does not follow on from the first. On a 16x2 module line 1 is `$00-$0F` and line 2 is `$40-$4F`; on a 20x4 the four lines start at `$00`, `$40`, `$14` and `$54`.

`LCDMOVECUR` and `LCDSCROLL` both wrap at the display extents, so counts larger than the display go round rather than stopping.

### Custom Characters

There are 8 user definable characters of 8 bytes each, 8 rows of 5 pixels, where only the low 5 bits of each byte are used and a set bit is a lit pixel. `LCDCGRAM` sets the byte offset into that memory — the character you want times 8, or any single row of any character — and `LCDCGBYTE` writes one row. Once defined, print the character with `CHR$(n)` for `n` of 0 to 7.


```
10 LCDCGRAM 0 : REM character 0
20 FOR I = 0 TO 7 : READ B : LCDCGBYTE B : NEXT
30 DATA 0,10,10,0,17,14,0,0
40 LCDCURPOS 0
50 LCDPRINT CHR$(0)
```

`LCDCGCHRS` is the same routine as `LCDPRINT` under a second name. Which one you reach for is about what you have in hand: `LCDCGBYTE` for numbers, `LCDCGCHRS` for a string of character codes.

### Cursor Enable/Blink Interactions

`LCDCURENABLE` and `LCDCURBLINK` each rewrite the whole HD44780 display control byte, so setting one clobbers the other — turning blink off leaves a solid cursor on, and turning the cursor off clears blink. That is consistent with my MS-BASIC version does and it is deliberately kept. `LCDCMD` is the way to set the odd combinations the two commands cannot express, cursor on with the display off and so on.

### LCD Initialization

The `LCDINIT` routine runs from `RES_vec` at reset, before the `[C]old/[W]arm` prompt, and brings the display up in 4 bit mode, 2 lines, 5x8 font, cursor on, blink off. It opens with a delay, because the HD44780 wants more than 15 ms after VCC comes up before it will take its first instruction and `RES_vec` gets there in microseconds. The loop is sized by `LCD_WARMUP` in `custom_commands.s`, `$30` giving 62 ms on a 1 MHz board and still clearing 15 ms at 4 MHz. Increase it if you clock faster than that.

</details>

## Inline Assembler

The ROM carries a two pass 6502/65C02 assembler. Assembly source lives inside the BASIC program as ordinary numbered lines, between `ASM` and `ENDASM`:

```
100 ASM
110 START LDA MSG,X
120       BEQ DONE
130       JSR $FFD2
140       INX
150       BNE START
160 DONE  RTS
170 MSG   TEXT "HELLO"
180       BYTE 0
190 ENDASM
200 CALL SYM("START")
```

Those lines are real BASIC lines. They `LIST`, they `SAVE` and `LOAD` with the program, and you edit them with the same line numbers as everything else.

### The Keywords

| Command | Argument | What it does |
| --- | --- | --- |
| `ASM` | — | opens a block. Assembles the program if the image is stale, then steps over the block |
| `ENDASM` | — | closes a block. Never executed |
| `ASSEMBLE [n]` | byte | assemble the whole program now. A non zero `n` prints a listing |
| `SYM("NAME")` | string | the address a label was given |
| `DASM start[,count]` | address, byte | disassemble `count` instructions, 20 by default |

<details>
<summary>
Inline Assembler Details
</summary>

## Inline Assembler Details

### Writing a Line

One instruction per line:

```
[|] [label] [mnemonic | directive [operand]] [; comment]
```

**A label is any first field that is not a mnemonic or a directive.** A trailing `:` on a label is accepted and ignored. Lower case is folded up, so `lda #$41` is fine, but text inside quotes is left exactly as typed.

### Indenting with `|`

EhBASIC throws away the spaces between a line number and the first character before it ever stores the line, so `120       BEQ DONE` comes back from `LIST` as `120 BEQ DONE`. Anything non-blank at that position stops the skipping, and that is what the optional `|` prefix is for:

```
100 ASM
110 |        LDX #$00
120 |LOOP    LDA MSG,X
130 |        BEQ DONE
140 |        JSR COUT
150 |        INX
160 |        BNE LOOP
170 |DONE    RTS
180 |MSG     TEXT "HELLO"
190 ENDASM
```

That is exactly what `LIST` gives back, and it assembles byte for byte identically to the same source without the prefixes — the assembler steps over the `|` and carries on. It is purely cosmetic and entirely optional.

A label can share the margin, as `|LOOP` and `|DONE` do above, so labels and code line up on the same column. A line that is nothing but `|`, or `|` followed by a comment, is simply blank.

`|` was picked because it has no meaning anywhere else: the tokenizer copies it straight through so it costs no token, no 6502 assembler uses it, and outside an `ASM` block it is a syntax error — which is what a stray one should be. It only has any effect as the first non-space character of a line inside a block.

It is only necessary to use `|` to indent if it would otherwise mean that only whitespace characters would precede an opcode/instruction:

```
100 ASM
110 |        LDX#$00  
120 LOOP     LDA MSG,X
130 |        BEQ DONE
140 |        JSR COUT
150 |        INX
160 |        BNE LOOP
170 DONE     RTS
```

The above are all valid combinations; you can use `|` on every line for consistency, or just where it is necessary to preserve indentation.

### Operands

Operands take literals, labels, one `+` or `-` offset, and a leading `<` or `>` for the low or high byte:

| Written | Means |
| --- | --- |
| `$1F` `$1234` | hex |
| `%10101010` | binary |
| `65` | decimal |
| `'A'` | one character |
| `LABEL` `LABEL+2` | a label, with an optional offset |
| `*` | the address of the instruction being assembled |
| `<LABEL` `>LABEL` | its low or high byte |

There is no precedence and no arithmetic beyond that single offset. This is not the BASIC expression evaluator and does not pretend to be — `LDA #VAL*2` is a syntax error, not a multiplication.

### Zero Page Needs `<`

**A symbolic operand always assembles as absolute unless you write `<` in front of it.** `LDA PTR` is three bytes even when `PTR` is `$80`; `LDA <PTR` is the two byte zero page form.

That is not an oversight. The width of an instruction has to be the same in both passes, or every address after it shifts between them and the whole image is wrong. A forward reference has no value yet in pass 1, so the only rule that can be honest is to decide the width from **how the operand is written** rather than from what it turns out to be worth. Literals narrow on their own — `LDA $80` is zero page, `LDA $0080` is absolute, exactly as written — and for a symbol `<` is how you say so. The two meanings coincide: for something that lives in zero page, its low byte *is* its address.

The modes that only exist in zero page — `($nn,X)`, `($nn),Y`, `($nn)`, and the `BBR`/`BBS` operand — have no absolute form to fall back on, so they take the low byte and complain if the value will not fit.

### Directives

| Directive | Does |
| --- | --- |
| `BYTE n[,n...]` | emit bytes |
| `WORD n[,n...]` | emit 16 bit words, low byte first |
| `TEXT "..."` | emit the characters between the quotes, exactly as typed |
| `NAME EQU n` | give a name a value without emitting anything |
| `DS n` | reserve `n` bytes, emitting nothing |
| `ORG n` / `*=n` | assemble at a fixed address from here on |

`ORG` is a one way door. Everything after it is assembled at real addresses, is **not** counted in the protected image, and is **not** protected from BASIC — it is the plain `POKE` contract, for when you want code at a specific place and will keep it clear yourself. Labels defined after an `ORG` are absolute.

### Where the Code Goes

With no `ORG`, you do not choose. Pass 1 measures the image, and the assembler then takes exactly that much off the top of RAM and lowers EhBASIC's memory ceiling to match, so string space and arrays can never grow into it:

```
                +--------------------+  end of memory as cold start found it
                |   work buffer      |  80 bytes
                +--------------------+
                |   symbol table     |  12 bytes a symbol, growing down
                +--------------------+
                |   code image       |  growing up
   Ememl  --->  +--------------------+  the ceiling, lowered to here
                |   string space     |  grows down from the ceiling as usual
```

`FRE(0)` drops by the whole reservation, and `SYM("NAME")` is how you find anything inside it. All the `ASM` blocks in a program are assembled in line order into **one** image with **one** symbol table, so a label defined in the first block is visible in the last.

Names are significant to eight characters. Twelve bytes an entry means 64 symbols costs 768 bytes.

### Assembling, and When Variables Get Cleared

`ASSEMBLE` does the whole program at once and reports where the code landed. `ASSEMBLE 1` adds a listing:

```
Ready
ASSEMBLE 1
3F9E  A9 41         START LDA #$41
3FA0  20 D2 FF      JSR $FFD2
3FA3  60            RTS

CODE AT $3F9E, 6
```

If you never run it, reaching an `ASM` block does the same thing on the spot, and from then on the block is simply stepped over.

**Lazy assembly clears variables if any string space is in use**, and says so:

```
*** ASSEMBLED, VARIABLES CLEARED
```

Taking memory off the top means moving the floor of string space, and strings already allocated cannot be picked up and put down somewhere else — so they have to go. Numeric variables, arrays and the running program are untouched, and if no string has been built yet nothing is cleared at all and no notice appears. Note that `A$="HELLO"` does **not** allocate: EhBASIC points the descriptor straight at the program text. It is computed strings that cost space.

Run `ASSEMBLE` from the immediate prompt, or make it the first line of the program, and the question never arises.

The image goes stale on any program line being entered or deleted, on `NEW`, and on `CLEAR`. A plain `RUN` does not invalidate it, so `ASSEMBLE` once and then `RUN` as often as you like.

</details>

### The Disassembler

`DASM` decodes the same instruction set the assembler emits, from anywhere in memory — including the ROM:

```
Ready
DASM $FE00,4
FE00  D8         CLD
FE01  58         CLI
FE02  80 0B      BRA $FE0F
FE04  C9 08      CMP #$08
```

Combined with `SYM` it is the quick way to check what a block actually produced: `DASM SYM("START"),8`.

### Errors

Assembly stops at the first fault and names the BASIC line, using EhBASIC's own error machinery — the assembler walks the program itself rather than executing it, so it sets the current line from the header before raising:

```
Ready
ASSEMBLE 0

Assembly syntax Error in line 110
Ready
```

| Error | Means |
| --- | --- |
| `Assembly syntax` | not a mnemonic or directive, a malformed operand, or no such addressing mode for that instruction |
| `Undefined label` | a label used but never defined; also `SYM()` on a name that is not there |
| `Duplicate label` | defined twice |
| `Branch out of range` | more than `-128`/`+127` away |
| `ASM block` | `ASM` with no `ENDASM`, or an `ENDASM` on its own |
| `Function call` | a value too big for the slot, such as `LDA #$1234` |
| `Out of memory` | the image and symbol table would collide with the arrays |

### How the Source Survives Tokenizing

Worth knowing, because it looks impossible at first. `BEQ DONE` is stored as `BEQ` followed by the **`DO` token** and `NE` — the tokenizer matches keywords at every character position, so `DONE`, `TOTAL`, `ROR`, `AND`, `INC` and plenty of others get chewed on the way in.

That turns out not to matter. The crunch has to be lossless, because `LIST` must be able to put a line back exactly as it was typed, so the assembler simply expands each line through `LAB_KEYT` — the same table `LIST` uses — before parsing it. The tokenizer is not modified at all, which means it does not matter what order you type or edit the lines in, `LIST` is correct for free, and lower case works because the tokenizer never matched it in the first place.

## Build Options

There are three classes of build options currently:

- **Debug Options** - Disabled by Default
- **LCD Commands** - Enabled by Default
- **Inline Assembler** - Enabled by Default

None of the debug machinery below is in the ROM unless you build for it. A plain `make` produces the stock image with no trace of it — no code, no cost, and the `POKE` address is inert.

```
make                      the stock ROM, LCD extensions and assembler in
make LCD=0                leave the HD44780 LCD extensions out entirely
make ASM=0                leave the inline assembler, SYM() and DASM out
make ASMCPU=n             which instruction set the assembler covers.
                          0 = NMOS 6502, 1 = 65C02 core, 2 = full WDC
                          W65C02S (the default)
make SENTINEL=n           build the program chain sentinel in, armed at n
                          headers per statement on reset. n=0 builds it in but
                          leaves it disarmed
make DEBUG=1              build the block watch, the 8009R bus stress test and
                          the page zero dump in
make SENTINEL=1 DEBUG=1   both
```

`LCD` defaults to **1**, so the LCD commands are in the stock ROM. `make LCD=0` takes out the driver, the thirteen keywords, their table entries in `basic.s` and the `LCDINIT` call at reset — the result is byte for byte the ROM you would have got before any of it was written. Build that way if your board has
no LCD on VIA port B, and see [LCD Commands](#lcd-commands) for why it matters.

`ASM` defaults to **1** as well. `make ASM=0` takes out the assembler, the disassembler, the opcode tables, all five keywords and their table entries, and the three flag clears in `basic.s` — and, like `LCD=0`, gives back a ROM byte for byte identical to the one before any of it existed. It costs about 4KB of ROM and nothing at all at run time until you use it, so there is little reason to turn it off unless you need the space.

`ASMCPU` picks how much of the instruction set the assembler and `DASM` know about. It defaults to **2**, the full WDC W65C02S, because that is the part a board built today will have. A Rockwell R65C02 has `RMB`/`SMB`/`BBR`/`BBS` but not `WAI` or `STP`, and a GTE/CMD G65SC02 has none of them — build those with `make ASMCPU=1`. Nothing in the ROM can tell what the silicon actually is, so the flag is the only guard: at the default, the assembler will cheerfully emit an instruction your CPU cannot execute. It does not change the ROM size either way, the tables are a fixed 256 bytes; a lower setting only blanks the entries above the level you pick, so they fail as `Assembly syntax` rather than assembling.

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
| `$800C-$BBF9` | EhBASIC, the minimal monitor, the LCD driver, the custom commands and the inline assembler |
| `$FC00-$FCFA` | bus stress test, pinned high on purpose |
| `$FE00-$FEFA` | WozMon |
| `$FFFA-$FFFF` | NMI, RESET and IRQ vectors |
| `$24-$2B` | WozMon zero page, taken from EhBASIC's unused `$13-$5A` |
| `$0280-$02FF` | WozMon line buffer, in the tail of page 2 above `Ibuffe` |
| `$0300-$03FF` | serial receive ring buffer, page aligned |
| `$E2-$E3`, `$E8-$ED` | chain sentinel / byte watch / bus test scratch |
| `$EE` | byte watch switch |
| `$2C-$58` | inline assembler working storage, out of EhBASIC's unused `$13-$5A` |
| top of RAM | the assembler's code image, symbol table and line buffer, below a lowered `Ememl` |

`$13-$23` is left entirely free. With `make ASM=0` the `$2C-$58` block is free as well, and the top of RAM is not touched.

WozMon lives at `$FE00` rather than its native `$FF00` because the vectors at `$FFFA` leave only 250 bytes there, and this version is slightly larger. It shares `CHRIN` and `CHROUT` with the rest of the ROM instead of carrying its own copy of the 65C51 transmit bug workaround, so it gets the same interrupt driven input, flow control and visual backspace as BASIC does.

### Adding Your Own Commands

`MONITOR` is a *real* EhBASIC keyword, not a `CALL`. Adding another follows the same four table edits in `basic.s` — a `TK_` equate, a `LAB_CTBL` vector, a keyword table entry under its first letter, and a `LAB_KEYT` entry for `LIST` to detokenize it — with the command body itself in `custom_commands.s`. The thirteen `LCD*` keywords are the same four edits done thirteen times.

Two things to know before you add one. `LAB_KEYT` is a **dense** array indexed `(token-$80)*4`, so a new entry has to go in at exactly the right ordinal or `LIST` prints garbage from that token on. And within a letter's dictionary table a longer keyword sharing a prefix must come **first** — `ENDASM` sits above `END` for the same reason `DOKE` sits above `DO`, or it would crunch as `END` followed by `ASM`.

There are **seven** token values left. The tokens run `$80` to `$F8`; a function keyword also needs `LAB_FTPL` and `LAB_FTBL` entries, and only tokens below `TK_TAB` can start a statement.

## Origins & EhBASIC

This version of EhBASIC is **derived from EhBASIC**, developed by Lee Davidson. The EhBASIC license allows for non-commerical use only. The most recent release and manual is hosted [here](https://github.com/Klaus2m5/6502_EhBASIC_V2.22), and a mirror of Lee's website can be found [here](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/).

> EhBASIC is free but not copyright free. For non commercial use there is only one restriction, any derivative work should include, in any binary image distributed, the string "Derived from EhBASIC" and in any distribution that includes human readable files a file that includes the above string in a human readable form (e.g., not as a comment in an HTML file).
