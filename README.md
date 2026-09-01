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

Note that the flow control is based on Ben's build that fixes the 65C51 UART bug, and requires running a connection from PA0 to CTS (via the MAX232, per the stock build, but will also work if wired directly via an FTDI-USB interface).

This update also includes a fix for an interrupt safety issue (see the commit details).

## Additional Enhancements

### Type-Ahead No Longer Loses Characters

Stock EhBASIC looks for `[CTRL-C]` by reading the input device itself, from `CTRLC`.  This runs after every direct command and between the statements of a running program. Whatever byte it finds is put in `ccbyte` under a countdown that only `GET` ever reads, so anything that is not a `[CTRL-C]` is swallowed.

With the buffered input implementation, per my first modification here, this would reliably eat a character whenever anything is typed or pasted ahead of the prompt: `NEW` followed immediately by `10 PRINT "A"`
would store line **0**.

To address this, `[CTRL-C]` is now trapped by the serial interrupt handler and recorded in a flag, and `VEC_CC` points at a check that reads _that_ flag instead of the input stream (`CCHECK` in `min_mon.s`). Nothing is taken out of the input, and `[CTRL-C]` still breaks a running program even with type-ahead queued up behind it. A `[CTRL-C]` typed at the `Ready` prompt is discarded once the line it was typed into is complete, so it does not stop whatever is entered next.

### True BACKSPACE Support

`BACKSPACE` now visually deletes the character it back-spaces over, rather than leaving it on the display.  This works for all input.

### WozMon Monitor in ROM

I like having WozMon available on my BE6502 ROMs, particularly those involving BASIC in some form (in addition to this EhBASIC version, I've also built a modified version of [Microsoft BASIC](https://github.com/idunmore/msbasic)).  You can switch back/forth between EhBASIC and WozMon.  Be sure to choose [W]arm start when coming back into EhBASIC if you want to retain the program that was there when you ran `MONITOR`.

## LCD Commands

**Note:** The BE6502 build this ROM is written for has an HD44780 character LCD on VIA port B, in **4-bit mode**.  The standard build videos don't show this, but details can be found on [Ben's Patreon](https://www.patreon.com/beneater/posts/4-bit-lcd-50900073).

| Port B | LCD |
| --- | --- |
| `PB0-PB3` | `D4-D7`, the 4 bit data nibble |
| `PB4` | `RS`, register select |
| `PB5` | `RW`, read/write |
| `PB6` | `E`, enable |

**A board with no LCD wired to port B can hang at reset**, because `LCDINIT` polls the display's busy flag and a floating input may (probably) never clear(s) it. So, if you're not using the LCD, run `make LCD=0` to disable (completely exclude) the LCD support, `JSR LCDINIT` included.  The default `make` build **includes** all of the LCD initialization and custom commands.

### The LCD Keywords

Thirteen keywords are provided. They are *real* EhBASIC keywords, not `CALL`s, so they tokenize and `LIST` like anything else. They are ported from the same command set my [Microsoft BASIC](https://github.com/idunmore/msbasic) build for this board carries; no translation or "porting" is needed (well, at least for the LCD commands!).

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

`LCDPRINT` takes a full `PRINT` style list, so `LCDPRINT "N=";N` works. `;` and `,` are both plain separators — there are no tab stops to move to on a 16 or 20 column display. There is no newline: the display has no implicit scroll (like a terminal; but you can issue LCDSCROLL commands to deliberately "scroll" the display left or right), so where the next character goes is determined by `LCDCURPOS` . Numbers are formatted exactly as `PRINT` formats them, which **includes** the *leading space* `PRINT` puts in front of a positive value (important when you are counting columns on a 16 wide display).

```
10 LCDCLS
20 LCDPRINT "TEMP:";T;" C"
30 LCDCURPOS 64 : REM second line
40 LCDPRINT "MAX:";M
```

### Cursor Positions

`LCDCURPOS` takes a DDRAM address, not a row and column, and the second line does not follow on from the first. On a 16x2 module line 1 is `$00-$0F` and line 2 is `$40-$4F`; on a 20x4 the four lines start at `$00`, `$40`, `$14` and `$54`.

`LCDMOVECUR` and `LCDSCROLL` both wrap at the display extents, so counts larger than the display will "wrap around" rather than being truncated.

### Custom Characters

There are 8 user definable characters of 8 bytes each, organized as 8 rows of 5 pixels, where only the low 5 bits of each byte are used and a set bit is an enabled ("on") pixel. `LCDCGRAM` sets the byte offset into that memory (the character index you want times 8), or any single row of any character — and `LCDCGBYTE` writes one row. Once defined, print the character with `CHR$(n)` for `n` of 0 to 7.


```
10 LCDCGRAM 0 : REM character 0
20 FOR I = 0 TO 7 : READ B : LCDCGBYTE B : NEXT
30 DATA 0,10,10,0,17,14,0,0
40 LCDCURPOS 0
50 LCDPRINT CHR$(0)
```

`LCDCGCHRS` is the same routine as `LCDPRINT`, provided as a context-alias. Which one you use depends on what you're doing: `LCDCGBYTE` for numbers, `LCDCGCHRS` for a string of character codes.

### Cursor Enable/Blink Interactions

`LCDCURENABLE` and `LCDCURBLINK` each rewrite the whole HD44780 display control byte, so setting one clobbers the other; both also enable the disaply.  Turning blink off leaves a solid cursor on, and turning the cursor off clears blink. This is consistent with my MS-BASIC version and is deliberate, based on the assumption that turning blinking on or off means you want both the display ON **and** the cursor displayed (or why change it?), and turning it off means you don't care if it was set to blink or not, but, again, if you're changing it you want it **displayed**.  If you want specific control for ALL options, you can track state in your code and use `LCDCMD` to send the required state flags.

### LCD Initialization

The `LCDINIT` routine runs on RESET; before the `[C]old/[W]arm` prompt, and brings the display up in 4 bit mode, 2 lines, 5x8 font, cursor on, blink off.  There is a built-in delay since the HD44780 requires its own initialization time.

</details>

## Inline Assembler

The default build now implemented a two pass 6502/65C02 assembler (so forward-references to labels/symbols is supported). Assembly source lives inside the BASIC program as ordinary numbered lines, between `ASM` and `ENDASM`:

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

These lines are treated as real BASIC lines. They `LIST`, they `SAVE` and `LOAD` with the program, and you edit them with the same line numbers as normal.

### The Keywords

| Command | Argument | What it Does/Returns |
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

EhBASIC removes/ignores spaces between a line number and the first non-whitespace character before it stores the line, so `120       BEQ DONE` is stored, and comes back from `LIST`, as `120 BEQ DONE`. Anything non-blank at that position stops the skipping, so the optional `|` prefix is provided to allow indenting ASM code.  Since each indent space is counted as a character, and takes up a byte of program storage (RAM), if memory is tight use fewer spaces on the indent and consider putting labels on their own lines (see below):

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

Entering the above will be exactly what `LIST` returns.  It assembles byte-for-byte identically to the same source without the indent prefixes.  It is purely cosmetic and entirely optional.

A label can share the margin, as `|LOOP` and `|DONE` do above, so labels and code line up on the same column. A line that is nothing but `|`, or `|` followed by a comment, is simply blank.

`|` was picked because it has no meaning anywhere else: the tokenizer copies it straight through so it costs no token, no 6502 assembler uses it, and outside an `ASM` block it is a syntax error — which is what a stray one should be. It only has any effect as the first non-space character of a line inside an ASM/ENDASM block.

It is only necessary to use `|` to indent if it would otherwise mean that only whitespace characters would precede an opcode/instruction:

```
100 ASM
110 |        LDX #$00  
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

That is not an oversight, but an artifact of some design (simplification) choices.  The width of an instruction has to be the same in both passes, or every address after it shifts between them and the whole image is wrong. On pass one, a forward-reference has no value (yet), so the only reasonable rule is to decide the width from **how the operand is written** rather than from what it _turns out_ to be. Literals narrow on their own — `LDA $80` is zero page, `LDA $0080` is absolute, exactly as written — and for a symbol `<` is the syntax for indicating that.  It is, perhaps, a bit of an adjustment from other, full-fledged assemblers, but here the two meanings coincide, and yield a useful simplification in implementation.  But, regardless ... for something that lives in *8zero page**, its low byte *is* its address.

The modes that only exist in zero page — `($nn,X)`, `($nn),Y`, `($nn)`, and the `BBR`/`BBS` operand — have no absolute form to fall back on, so they take the low byte and complain if the value doesn't fit.

### Directives

| Directive | Does |
| --- | --- |
| `BYTE n[,n...]` | emit bytes |
| `WORD n[,n...]` | emit 16 bit words, low byte first |
| `TEXT "..."` | emit the characters between the quotes, exactly as typed |
| `NAME EQU n` | give a name a value without emitting anything |
| `DS n` | reserve `n` bytes, emitting nothing |
| `ORG n` / `*=n` | assemble at a fixed address from here on |

`ORG` has an absolute, one-way, effect. **Everything** after it is assembled at real addresses, is **not** counted in the protected image, and is **not** protected from BASIC (if you stick an ORG value in the middle of something critical, this assembler will gleefully, and obvliviously, address code per your command ...).  This means LABELS/SYMBOL defined after an `ORG` are absolute.

### Code Location

With no `ORG`, the assembler chooses. Pass 1 measures the image, and the assembler then takes exactly that much from the top of RAM and lowers EhBASIC's memory ceiling to match, so string space and arrays can never grow into it:

```
                +--------------------+  end of memory as cold start found it
                |   work buffer      |  80 bytes
                +--------------------+
                |   symbol table     |  12 bytes per symbol, growing down
                +--------------------+
                |   code image       |  growing up
   Ememl  --->  +--------------------+  the ceiling, lowered to here
                |   string space     |  grows down from the ceiling as usual
```

`FRE(0)` drops by the whole amount of the reserved areas.  `SYM("NAME")` lets you perform look ups, based on LABEL/SYMBOL names to find addresses within in.  All the `ASM` blocks in a program are assembled in line order into **one** image with **one** symbol table, so a LABEL or SYMBOL defined in the first block is visible in the last (and, of course, all others).

Names are significant to **eight** characters. Twelve bytes per entry means 64 symbols costs 768 bytes.

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

If you never run it, reaching an `ASM` block does an implicit `ASSEMBLE` and from then on the block is simply stepped over.

**Lazy assembly clears variables if any string space is in use**; it will report this as:

```
*** ASSEMBLED, VARIABLES CLEARED
```

Taking memory off the top means moving the floor of string space, and strings already allocated cannot be picked up and put down somewhere else; this leaves the only options as clearing/resetting them. Numeric variables, arrays and the running program are untouched, and if no string has been built yet nothing is cleared at all and no notice appears. Note that `A$="HELLO"` does **not** allocate: EhBASIC points the descriptor straight at the program text. It is **computed** strings that cost space.

To avoid issues here, you can either run `ASSEMBLE` from the immediate prompt, or make it the **first line of the program**.

The image goes stale on any program line being entered or deleted, on `NEW`, and on `CLEAR`. A plain `RUN` does not invalidate it, so `ASSEMBLE` once and then `RUN` as often as you like.  Note that if you're mutating data defined in an ASM/ENDASM block, re-running a program without changes will see the MUTATED values rather than the defined ones; it takes a manual ASSEMBLE (or a code change) to force the relevant bytes to be reemitted to memory.

</details>

### Errors

Assembly stops at the first fault and names the BASIC line, using EhBASIC's own error handling; the assembler walks the program itself rather than executing it, so it sets the current line from the header before raising the error:

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

Combined with `SYM` it is a quick and simple way to check what an ASM/ENDASM block actually produced: `DASM SYM("START"),8`.

## RENUMBER

`RENUMBER` renumbers the stored program and fixes up every line number it refers to, so the program still runs afterwards. It is a *real* EhBASIC keyword like the rest of the additions here.

| Command | Argument | What it does |
| --- | --- | --- |
| `RENUMBER [new[,inc[,old]]]` | line, line, line | renumber the program from line `old` to start at `new` and step by `inc` |

`new` defaults to `10`, `inc` defaults to `10`, and `old` defaults to the start of the program, so a bare `RENUMBER` gives you 10, 20, 30 and so on.

```
Ready
RENUMBER

Ready
RENUMBER 1000,10,100
```

The second of those renumbers the lines from 100 upwards to start at 1000 and step by 10, and leaves everything below 100 exactly as it was — including any reference to it.

The arguments are **strictly positional**. A missing one takes its default, but it cannot be skipped over: `RENUMBER 1000` is fine, `RENUMBER ,10` and `RENUMBER 10,,5` are `Syntax Error`.

References are updated after `GOTO`, `GOSUB`, `THEN`, `ELSE`, `RUN`, `RESTORE` and `LIST`, and through the comma list of an `ON <n> GOTO` or `ON <n> GOSUB`. `IF <expr> GOTO <n>` needs nothing special, it is the `GOTO` case. Numbers inside a string, a `REM` or a `DATA` item are left alone, because none of those are keyword positions.

```
Ready
LIST

100 PRINT "START"
110 GOSUB 300
120 IF X=1 THEN 200 ELSE 130
130 REM GOTO 100 IS JUST TEXT
140 ON X GOTO 100,200,300
200 PRINT "TWO"
210 RETURN
300 X=1
310 RETURN
Ready
RENUMBER

Ready
LIST

10 PRINT "START"
20 GOSUB 80
30 IF X=1 THEN 60 ELSE 40
40 REM GOTO 100 IS JUST TEXT
50 ON X GOTO 10,60,80
60 PRINT "TWO"
70 RETURN
80 X=1
90 RETURN
Ready
```

`RENUMBER` finishes at the `Ready` prompt, the same as `LIST` or `NEW`, and it clears the variables the way typing a program line in does. `CONT` will not work across it, for the same reason. It also disables `ON IRQ` and `ON NMI` — those hold the *address* of the line they were given rather than its number, and renumbering moves every line, so leaving them armed would point an interrupt at whatever now sits there.

<details>
<summary>
RENUMBER Details
</summary>

### Errors

| Error | Means |
| --- | --- |
| `RENUMBER` | the arguments do not work against this program — see below |
| `Syntax` | a malformed argument list, including a skipped argument |
| `Out of memory` | there is not enough free RAM to widen the references — see below |

`RENUMBER Error` covers four things:

- an increment of `0`, which would give every line the same number
- a `new` that does not clear the last line kept below `old`. `RENUMBER 100,10,200` on a program with a line 150 is refused, because the renumbered run would land on top of the lines that keep their numbers
- a program long enough that the numbering would run past **63999**, which is the highest line number EhBASIC will parse
- `RENUMBER` reached from inside a running program. Renumbering while running would move the code out from under the execute pointer and the `GOSUB` and `FOR` structures on the stack, so it is a direct mode command only

These conditions are caught before anything his changed, so a refused `RENUMBER` leaves the program exactly as it was.  Similarly, if there is insufficient memory to complete a renumber, you simply get an `Out of memory` error, and no code is changed.

### Undefined References

A reference to a line that does not exist cannot be renumbered, so it is left as it stands and reported once the renumber is over:

```
Ready
RENUMBER 500,5

Undefined 9999 in line 500
Ready
```

The line named is its **new** number, so you can `LIST` it straight away. The renumber still happens — one stale `GOTO` does not stop you tidying the program up, it was already broken and it is still broken in the same way.

### Why It Needs Free Memory

A line number lives in the program in two quite different forms. The one in the line header is a binary word, and rewriting it costs nothing. The one after `GOTO` is plain ASCII digits sitting in the tokenized text, which `LAB_GFPN` re-reads every time the statement runs. So `GOTO 90` becoming `GOTO 1000` makes its line two bytes longer.

Working out what a reference becomes means looking its old number up among the line headers, which needs the program in one piece and still on its old numbers. That rules out doing the lookups during a pass that is also shuffling the text about. So `RENUMBER` widens every reference to a fixed five digits first — five being the most a line number can take — swaps the numbers over at that fixed width, where nothing moves at all, and then takes the padding back off.

The free RAM it wants is what that widening costs: at most four bytes per reference, and in practice much less, since most references are already three or four digits. The 500 line `spcwar` needs 237 bytes. It is checked, and refused with `Out of memory`, before anything is modified.

### Speed

`RENUMBER` looks every reference up by walking the line headers, so the work grows with the program times the number of references in it. A 500 line program with a few hundred references takes about three seconds on a 1 MHz board, and well under one on a clocked up one.

There is no progress output, and `[CTRL-C]` will not stop it. That is deliberate: there is no point part way through where the program would still be coherent. A `[CTRL-C]` typed while it runs is discarded at the prompt afterwards, the same as one typed at the prompt itself.

</details>

## Build Options

There are two classes of build options currently:

- **LCD Commands** - Enabled by Default
- **Inline Assembler** - Enabled by Default


```
make                      the stock ROM, LCD extensions and assembler in
make LCD=0                leave the HD44780 LCD extensions out entirely
make ASM=0                leave the inline assembler, SYM() and DASM out
make ASMCPU=n             which instruction set the assembler covers.
                          0 = NMOS 6502, 1 = 65C02 core, 2 = full WDC
                          W65C02S (the default)
```

`LCD` defaults to **1**, so the LCD commands are in the stock ROM. `make LCD=0` takes out the driver, the thirteen keywords, their table entries in `basic.s` and the `LCDINIT` call at reset — the result is byte for byte the ROM you would have got before any of it was written. Build that way if your board has
no LCD on VIA port B, and see [LCD Commands](#lcd-commands) for why it matters.

`ASM` defaults to **1** as well. `make ASM=0` takes out the assembler, the disassembler, the opcode tables, all five keywords and their table entries, and the three flag clears in `basic.s` — and, like `LCD=0`, gives back a ROM byte for byte identical to the one before any of it existed. It costs about 4KB of ROM and nothing at all at run time until you use it, so there is little reason to turn it off unless you need the space.

`ASMCPU` picks how much of the instruction set the assembler and `DASM` know about. It defaults to **2**, the full WDC W65C02S, because that is the part a board built today will have. A Rockwell R65C02 has `RMB`/`SMB`/`BBR`/`BBS` but not `WAI` or `STP`, and a GTE/CMD G65SC02 has none of them — build those with `make ASMCPU=1`. Nothing in the ROM can tell what the silicon actually is, so the flag is the only guard: at the default, the assembler will cheerfully emit an instruction your CPU cannot execute. It does not change the ROM size either way, the tables are a fixed 256 bytes; a lower setting only blanks the entries above the level you pick, so they fail as `Assembly syntax` rather than assembling.

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
| `$8000-$800B` | entry jump table |
| `$800C-$C143` | EhBASIC, the minimal monitor, the LCD driver, the custom commands and the inline assembler |
| `$FE00-$FEFA` | WozMon |
| `$FFFA-$FFFF` | NMI, RESET and IRQ vectors |
| `$24-$2B` | WozMon zero page, taken from EhBASIC's unused `$13-$5A` |
| `$0280-$02FF` | WozMon line buffer, in the tail of page 2 above `Ibuffe` |
| `$0300-$03FF` | serial receive ring buffer, page aligned |
| `$2C-$58` | inline assembler working storage, out of EhBASIC's unused `$13-$5A` |
| `$13-$23` | `RENUMBER` working storage, the rest of that same unused block |
| top of RAM | the assembler's code image, symbol table and line buffer, below a lowered `Ememl` |

`$59-$5A` is all that is left free. With `make ASM=0` the `$2C-$58` block is free as well, and the top of RAM is not touched. `RENUMBER` is not optional, so its `$13-$23` is spoken for in every build, but nothing in it has to survive the command.

WozMon lives at `$FE00` rather than its native `$FF00` because the vectors at `$FFFA` leave only 250 bytes there, and this version is slightly larger. It shares `CHRIN` and `CHROUT` with the rest of the ROM instead of carrying its own copy of the 65C51 transmit bug workaround, so it gets the same interrupt driven input, flow control and visual backspace as BASIC does.

### Adding Your Own Commands

`MONITOR` is a *real* EhBASIC keyword, not a `CALL`. Adding another follows the same four table edits in `basic.s` — a `TK_` equate, a `LAB_CTBL` vector, a keyword table entry under its first letter, and a `LAB_KEYT` entry for `LIST` to detokenize it — with the command body itself in `custom_commands.s`. The thirteen `LCD*` keywords are the same four edits done thirteen times.

A command that is **not** behind a build flag wants its token in the unconditional run, above the `.if ASM_BUILT` and `.if LCD_BUILT` groups, the way `RENUMBER` has it. Put it after them and its token value, and so its `LAB_CTBL` and `LAB_KEYT` ordinals, move about depending on what else got built. The same goes for a new error code in `LAB_BAER`. And anything in `custom_commands.s` that is always built needs whatever it borrows from EhBASIC exported unconditionally from `min_mon.s` — a symbol can only be exported once, so it has to come out of the `HELP_BUILT` and `ASM_BUILT` blocks when it goes into the unconditional one.

Two things to know before you add one. `LAB_KEYT` is a **dense** array indexed `(token-$80)*4`, so a new entry has to go in at exactly the right ordinal or `LIST` prints garbage from that token on. And within a letter's dictionary table a longer keyword sharing a prefix must come **first** — `ENDASM` sits above `END` for the same reason `DOKE` sits above `DO`, or it would crunch as `END` followed by `ASM`.

There are **six** token values left. The tokens run `$80` to `$F9`; a function keyword also needs `LAB_FTPL` and `LAB_FTBL` entries, and only tokens below `TK_TAB` can start a statement.

## Origins & EhBASIC

This version of EhBASIC is **derived from EhBASIC**, developed by Lee Davidson. The EhBASIC license allows for non-commerical use only. The most recent release and manual is hosted [here](https://github.com/Klaus2m5/6502_EhBASIC_V2.22), and a mirror of Lee's website can be found [here](http://retro.hansotten.nl/6502-sbc/lee-davison-web-site/).

> EhBASIC is free but not copyright free. For non commercial use there is only one restriction, any derivative work should include, in any binary image distributed, the string "Derived from EhBASIC" and in any distribution that includes human readable files a file that includes the above string in a human readable form (e.g., not as a comment in an HTML file).
