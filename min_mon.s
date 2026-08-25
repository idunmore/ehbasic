; minimal monitor for EhBASIC and 6502 simulator V1.05
; tabs converted to space, tabwidth=6

; To run EhBASIC on the simulator load and assemble [F7] this file, start the simulator
; running [F6] then start the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

; The MONITOR command body lives in custom_commands.s. importing it here,
; ahead of the include, keeps the edits to basic.s down to table entries

; the LCD extensions default to in, so a missing LCD_ENABLE means yes, not no.
; ca65 resolves .if as it goes, so this has to come before the first test of
; it, both here and in basic.s where it guards the LCD keywords' table entries

.ifdef LCD_ENABLE
LCD_BUILT    = LCD_ENABLE
.else
LCD_BUILT    = 1
.endif

; the inline assembler defaults to in on the same terms, and for the same
; reason has to be settled before basic.s is included. ASM_CPU picks which
; instruction set the opcode tables carry, see assembler.s

.ifdef ASM_ENABLE
ASM_BUILT    = ASM_ENABLE
.else
ASM_BUILT    = 1
.endif

.ifdef ASM_CPU
ASM_CPU_SEL  = ASM_CPU
.else
ASM_CPU_SEL  = 2
.endif

      .import LAB_MONITOR

; RENUMBER lives in custom_commands.s too, and is always built. basic.s names
; it in LAB_CTBL, so it has to be imported ahead of the include as well

      .import LAB_RENUMBER

; the LCD driver and the LCD keyword bodies live in custom_commands.s too.
; basic.s names the command entry points in LAB_CTBL and LCDINIT is called from
; RES_vec below, so both have to be imported ahead of the include

.if LCD_BUILT
      .import LCDINIT
      .import LCDCMD, LCDPRINT, LCDCGCHRS, LCDCLS, LCDHOME
      .import LCDCURPOS, LCDDDRAM, LCDCGRAM, LCDCGBYTE
      .import LCDCURENABLE, LCDCURBLINK, LCDMOVECUR, LCDSCROLL
.endif

; the inline assembler's command bodies live in assembler.s and disasm.s.
; basic.s names all five entry points in LAB_CTBL and LAB_FTBL, so they have
; to be imported ahead of the include as well

.if ASM_BUILT
      .import LAB_ASM, LAB_ENDASM, LAB_ASSEMBLE, LAB_DASM, LAB_SYM
.endif

; CHRIN and CHROUT are the serial primitives, wozmon.s uses them rather than
; carrying its own copy of the 65C51 transmit bug workaround

      .export CHRIN, CHROUT

; exported only so that its address shows up in the link map. where the stress
; loop lands in the ROM turns out to matter, see BUSTEST below

.ifdef DEBUG_TOOLS
      .export BUSTEST
.endif

; set by the interrupt handler when a [CTRL-C] comes in, tested by CCHECK
; below. it has to be equated ahead of the include so that basic.s assembles
; its one reference to it as zero page

BRK_FLAG     = $E7            ; [CTRL-C] seen by the interrupt handler

; the assembler's "image is good" flag. basic.s clears it from three places -
; a program line edit, NEW and CLEAR - so it has to be equated ahead of the
; include, the same way BRK_FLAG is. the rest of the assembler's zero page is
; declared in assembler.s and starts at $2D, immediately above this

.if ASM_BUILT
ASM_FLG      = $2C            ; $00 no image, $80 image assembled and good
      .exportzp ASM_FLG
.endif

; build time options, set from the Makefile
;
;   SENTINEL_INIT  define to build the program chain sentinel in. the value is
;                  what $EC holds after reset, so 1 arms it at one header per
;                  statement and 0 leaves it disarmed until a POKE 236,n
;   DEBUG_TOOLS    define to build the block watch, the 8009R bus stress test
;                  and the page zero dump in
;
; neither is defined by a plain "make", so the stock ROM carries none of it.
;
;   LCD_ENABLE     the odd one out, set to 0 to leave the HD44780 LCD
;                  extensions out. it is always passed by the Makefile and
;                  defaults to 1, so the stock ROM does carry them. tested via
;                  LCD_BUILT, which is worked out at the top of this file

.ifdef SENTINEL_INIT
SENT_BUILT   = 1
.else
SENT_BUILT   = 0
SENTINEL_INIT = 0
.endif

.ifdef DEBUG_TOOLS
DIAG_BUILT   = 1
.else
DIAG_BUILT   = 0
.endif

TOOLS_BUILT  = SENT_BUILT + DIAG_BUILT

; the program chain sentinel's working storage, up here for the same reason

CHK_SVR      = $E2            ; start of variables when the walk was anchored
CHK_PTR      = $E8            ; header being checked, low/high
CHK_NUM      = $EA            ; line number of the header before it, low/high
CHK_N        = $EC            ; headers checked per call, $00 = sentinel off
CHK_CNT      = $ED            ; headers left to do in this call

; the byte watch's working storage. it deliberately shares the chain
; sentinel's bytes, only one of the two runs at a time

WCH_PTR      = $E8            ; base address of the block being watched
WCH_IDX      = $EA            ; how far the round robin has got through it
WCH_SAV      = $ED            ; the caller's Y, held over the check
WCH_ON       = $EE            ; $00 = off, $01 = arm, b7 set once copied

WCH_COPY     = $0280          ; the copy of the block, in WozMon's line buffer,
                              ; which is free unless WozMon is actually running
WCH_LEN      = $80            ; bytes watched. must be a power of two
WCH_STEP     = 4              ; bytes checked per statement

      .include "basic.s"

; the LCD command bodies in custom_commands.s are a port of code written for
; Microsoft BASIC, so they need EhBASIC's parameter fetching. these have to be
; exported from here rather than from basic.s because this is the unit that
; includes it. see the table at the top of custom_commands.s for what each one
; stood in for on the MS-BASIC side

; the assembler in assembler.s needs a good deal of the same machinery, so the
; parts both want are exported once, under a flag that is set when either is
; built. exporting the same symbol twice is an error, hence the split

HELP_BUILT   = LCD_BUILT + ASM_BUILT

; RENUMBER is not optional, so everything it wants is exported unconditionally
; and taken out of the two blocks below. a symbol can only be exported once
;
;   LAB_GBYT   scan at the execute pointer, Z set at end of statement
;   LAB_IGBY   increment the execute pointer and scan
;   LAB_GFPN   get a line number, ASCII digits to Itempl/h, caps at 63999
;   LAB_SNER   syntax error and warm start
;   LAB_XERR   raise error number X and warm start
;   LAB_11CF   open up space in memory, "Out of memory" if it will not fit
;   LAB_1477   reset execution, clear variables, flush the stack
;   LAB_1274   the warm start: "Ready" and wait for the next command
;   LAB_18C3   print null terminated string from AY
;   LAB_295E   print XA as an unsigned integer, used for line numbers
;   LAB_147A   the body of CLEAR, resets variables and string space
;
; the zero page names are the program and memory pointers RENUMBER walks and
; rewrites. the TK_ ones are byte equates, hence .exportzp, the same way the
; assembler takes TK_ASM and TK_ENDASM below

      .export LAB_GBYT, LAB_IGBY, LAB_GFPN, LAB_SNER
      .export LAB_XERR, LAB_11CF, LAB_147A, LAB_1477, LAB_1274
      .export LAB_18C3, LAB_295E
      .exportzp Smeml, Svarl, Itempl, Clineh
      .exportzp Nbendl, Obendl, Ostrtl
      .exportzp TK_GOTO, TK_GOSUB, TK_THEN, TK_ELSE, TK_LIST
      .exportzp TK_RUN, TK_RESTORE, TK_REM, TK_DATA, TK_MINUS

.if HELP_BUILT
      .export LAB_GTBY, LAB_EVNM, LAB_EVEX
      .export LAB_22B6
      .exportzp Dtypef, ut1_pl
.endif

.if LCD_BUILT
      .export LAB_EVIR, LAB_296E, LAB_20AE
      .exportzp FAC1_2, FAC1_3
.endif

; and the assembler's own set. what it shares with RENUMBER - LAB_18C3,
; LAB_295E, LAB_XERR, LAB_147A and most of the page zero names - is in the
; unconditional block above, so only the parts nothing else wants are left
; here
;
;   LAB_F2FX   FAC1 float to fixed, result in Itempl/h and in AY
;   LAB_AYFC   signed 16 bit AY to FAC1, how SYM() returns its answer
;   LAB_1C01   scan for "," else syntax error
;   LAB_PRNA   print the character in A, tracking the terminal column. this
;              rather than CHROUT, or a listing would leave TPos wrong and
;              upset PRINT's tab stops and line wrapping afterwards
;   LAB_CRLF   new line, and the thing that resets that column count
;   LAB_KEYT   the LIST keyword table, which the line expander walks
;   TK_ASM     needed to spot the start of a block while walking the program
;   TK_ENDASM  and the end of one

.if ASM_BUILT
      .export LAB_F2FX, LAB_AYFC, LAB_1C01, LAB_CRLF
      .export LAB_KEYT, LAB_PRNA
      .exportzp TK_ASM, TK_ENDASM
      .exportzp Earryl, Sstorl, Ememl, Bpntrl, Clinel
.endif

; put the IRQ and MNI code in RAM so that it can be changed

IRQ_vec     = VEC_SV+2        ; IRQ code vector
NMI_vec     = IRQ_vec+$0A     ; NMI code vector

; now the code. all this does is set up the vectors and interrupt code
; and wait for the user to select [C]old or [W]arm start. nothing else
; fits in less than 128 bytes

; fixed ROM entry points. WozMon has no way to name a label, so these have to
; sit at addresses that do not move as the code around them grows, hence a
; jump table pinned to the bottom of the ROM by basic.cfg rather than raw code

      .segment "ENTRY"

      JMP   RES_vec           ; $8000 sign on, then the [C]old/[W]arm prompt
      JMP   LAB_COLD          ; $8003 force a cold start
      JMP   LAB_WARM          ; $8006 force a warm start, no prompt. resumes
                              ;       the BASIC program that is in memory
.if DIAG_BUILT
      JMP   BUSTEST           ; $8009 RAM bus stress test, see BUSTEST below
.else
      JMP   RES_vec           ; $8009 no bus stress test in this build. the slot
                              ;       stays so the three above it never move,
                              ;       and lands somewhere harmless
.endif

      .segment "CODE"         ; pretend this is in a 1/8K ROM

; reset vector points here

RES_vec
      CLD                     ; clear decimal mode
      LDX   #$FF              ; empty stack
      TXS                     ; set the stack
      JSR   ACIAsetup         ; init ring buffer and ACIA (receiver IRQ enabled)
.if LCD_BUILT
      JSR   LCDINIT           ; bring the LCD up. port B, so it does not collide
                              ; with the flow control bit ACIAsetup put on port A
.endif
.if SENT_BUILT
      LDA   #SENTINEL_INIT    ; the chain sentinel's setting at reset, fixed
      STA   CHK_N             ; .. at build time. POKE 236,n overrides it
      STZ   CHK_PTR+1         ; walk pointer parked so the first call starts it
.endif
.if DIAG_BUILT
      STZ   WCH_ON            ; block watch off
.endif

; set up vectors and interrupt code, copy them to page 2

      LDY   #END_CODE-LAB_vec ; set index/count
LAB_stlp
      LDA   LAB_vec-1,Y       ; get byte from interrupt code
      STA   VEC_IN-1,Y        ; save to RAM
      DEY                     ; decrement index/count
      BNE   LAB_stlp          ; loop if more to do

; the RAM interrupt code is only valid now the copy above has run, so this is
; the earliest point at which interrupts can safely be let in

      CLI                     ; enable interrupts, receive buffer goes live

; now do the signon message, Y = $00 here

LAB_signon
      LDA   LAB_mess,Y        ; get byte from sign on message
      BEQ   LAB_nokey         ; exit loop if done

      JSR   V_OUTP            ; output character
      INY                     ; increment index
      BNE   LAB_signon        ; loop, branch always

LAB_nokey
      JSR   V_INPT            ; call scan input device
      BCC   LAB_nokey         ; loop if no key

      AND   #$DF              ; mask xx0x xxxx, ensure upper case
      CMP   #'W'              ; compare with [W]arm start
      BEQ   LAB_dowarm        ; branch if [W]arm start

      CMP   #'C'              ; compare with [C]old start
      BNE   RES_vec           ; loop if not [C]old start

      JMP   LAB_COLD          ; do EhBASIC cold start

LAB_dowarm
      JMP   LAB_WARM          ; do EhBASIC warm start

; Interrupt driven 65C51 I/O for EhBASIC, with a 256 byte circular receive
; buffer and hardware flow control via VIA port A bit 0.
;
; PA0 low  = "keep sending", PA0 high = "stop sending". It is asserted by the
; IRQ handler once the buffer holds HIGH_WATER bytes and released by CHRIN
; once the backlog drops below LOW_WATER. PA0 must be wired to the CTS input
; of the host's serial adapter for this to have any effect.

ACIA_DATA    = $5000          ; read = RX, write = TX
ACIA_STATUS  = $5001
ACIA_CMD     = $5002
ACIA_CTRL    = $5003

PORTA        = $6001          ; VIA port A, bit 0 drives host CTS
DDRA         = $6003          ; VIA port A data direction

HIGH_WATER   = $F0            ; buffer fill at which we tell the host to stop
LOW_WATER    = $B0            ; buffer fill at which we let it start again
BUF_FULL     = $FF            ; buffer holds $FF bytes, not $100. the pointers
                              ; are equal when it is empty, so a fill of $00
                              ; could not be told apart from a full buffer

; the ring buffer must be page aligned, the pointers are single bytes and rely
; on wrapping at the page boundary. $E4-$EE is unused by EhBASIC (see basic.s)

READ_PTR     = $E4            ; ring buffer read index
WRITE_PTR    = $E5            ; ring buffer write index
RX_TEMP      = $E6            ; holds a received byte over the flow control check
                              ; BRK_FLAG is $E7, equated above the include

      .segment "INPUT_BUFFER"

INPUT_BUFFER:
      .res  $100              ; 256 byte circular receive buffer

      .segment "CODE"

ACIAsetup
      JSR   INIT_BUFFER       ; empty the ring buffer, release host CTS
      LDA   #$00              ; write anything to status register for program reset
      STA   ACIA_STATUS
      LDA   #$1F              ; %0001 1111 = 19200 Baud
                              ;              External receiver
                              ;              8 bit words
                              ;              1 stop bit
      STA   ACIA_CTRL         ; set control register
      LDA   #$89              ; %1000 1001 = Parity mode disabled
                              ;              Receiver normal mode (no echo)
                              ;              RTSB Low, trans int disabled
                              ;              Receiver IRQ enabled
                              ;              Data terminal ready (DTRB low)
      STA   ACIA_CMD          ; set command register
      RTS

; initialise the circular input buffer and make PA0 an output, driven low so
; the host is clear to send
;
; Modifies: flags, A

INIT_BUFFER
      LDA   READ_PTR          ; buffer is empty when write index ..
      STA   WRITE_PTR         ; .. matches read index
      STZ   BRK_FLAG          ; no [CTRL-C] seen yet
      LDA   #$01              ; PA0 to output, the rest stay as inputs
      STA   DDRA
      LDA   #$FE
      AND   PORTA             ; clear PA0 ..
      STA   PORTA             ; .. host is clear to send
      RTS

; write the byte in A to the circular input buffer
;
; Modifies: flags, X

WRITE_BUFFER
      LDX   WRITE_PTR
      STA   INPUT_BUFFER,X
      INC   WRITE_PTR
      RTS

; read a byte from the circular input buffer into A
;
; Modifies: flags, A, X

READ_BUFFER
      LDX   READ_PTR
      LDA   INPUT_BUFFER,X
      INC   READ_PTR
      RTS

; return in A the number of unread bytes in the circular input buffer
;
; Modifies: flags, A

BUFFER_SIZE
      LDA   WRITE_PTR
      SEC
      SBC   READ_PTR
      RTS

; non halting scan of the input device for EhBASIC's V_INPT vector. returns
; with carry set and the byte in A, or carry clear if the buffer is empty.
;
; no echo here, EhBASIC echoes for itself via LAB_PRNA so that it can keep
; track of the terminal column, and GET must not echo at all
;
; the byte must be the last thing loaded into A. EhBASIC tests Z on return to
; discard NULLs, so a PLX or PLA after it would leave the wrong flags behind
;
; Modifies: flags, A

CHRIN
      PHX                     ; save X, EhBASIC holds its line index there
      JSR   BUFFER_SIZE       ; anything waiting?
      BEQ   @no_keypressed    ; no, exit with carry clear

      JSR   READ_BUFFER       ; take the oldest byte
      STA   RX_TEMP           ; hold it over the flow control check
      JSR   BUFFER_SIZE       ; how much backlog is left?
      CMP   #LOW_WATER
      BCS   @mostly_full      ; still too full to restart the host

      LDA   #$FE
      AND   PORTA             ; clear PA0 ..
      STA   PORTA             ; .. host is clear to send again
@mostly_full:
      PLX                     ; restore X
      SEC                     ; flag byte received
      LDA   RX_TEMP           ; get the byte, sets Z/N on it and leaves C alone
      RTS

@no_keypressed:
      PLX                     ; restore X
      CLC                     ; flag no byte received
no_load                       ; empty load vector for EhBASIC
no_save                       ; empty save vector for EhBASIC
      RTS

; send the byte in A to the output device for EhBASIC's V_OUTP vector. the
; delay is the workaround for the 65C51 transmit bug, the status register
; never reports the transmitter as empty so it cannot be polled
;
; Modifies: flags

CHROUT
      PHA                     ; save A
      STA   ACIA_DATA         ; write byte
      LDA   #$FF              ; initialise delay loop
@txdelay:
      DEC                     ; decrement A
      BNE   @txdelay          ; until A gets to 0
      PLA                     ; restore A
      RTS

; EhBASIC's [CTRL-C] check, reached through VEC_CC (see PG2_TABS in basic.s).
;
; this replaces the stock CTRLC, which scans the input device itself and keeps
; whatever it finds in ccbyte under a countdown that only GET ever reads. with
; input buffered that reliably swallows a typed or pasted character every time
; a direct command runs or a program passes a statement boundary. the received
; byte is examined by the interrupt handler instead, so nothing is taken out of
; the input stream here and a [CTRL-C] is still seen even with type ahead
; queued up behind it
;
; falls through to EhBASIC's own ON IRQ/ON NMI checks, exactly as CTRLC does

CCHECK
.if TOOLS_BUILT
      JSR   SENTINEL          ; costs a load and a branch unless something is
                              ; actually switched on
.endif

      LDA   ccflag            ; get [CTRL-C] check flag
      BNE   @nobreak          ; exit if inhibited

      LDA   BRK_FLAG          ; has the interrupt handler seen a [CTRL-C]?
      BEQ   @nobreak          ; no, nothing to do

      STZ   BRK_FLAG          ; take it, one [CTRL-C] is one break
      LDA   #$03              ; [CTRL-C], LAB_1636 tests for it
      JMP   LAB_1636          ; go stop the program

@nobreak:
      JMP   LAB_FBA2          ; go do the interrupt checks and return

; ---------------------------------------------------------------------------
.if TOOLS_BUILT
; ---------------------------------------------------------------------------
; program chain sentinel
;
; a debug aid for the "a line goes missing part way through a long RUN" bug.
; every instance of it so far has been a single byte written into a line
; header, the high byte of the line number, which throws that line out of
; order and hides it, and everything after it, from LIST <n>. it has never
; been reproduced under emulation, so this is here to catch it on the board
;
; it is called from CCHECK, which EhBASIC reaches between statements and
; between LISTed lines. each call walks a few line headers, picking up where
; the last call left off, and checks that every line number is greater than
; the one before it and that every link still points inside the program. when
; one is not it reports and breaks to Ready with the program untouched, so it
; can be LISTed or dumped from the MONITOR
;
; it is off until it is switched on, and the count is also the switch:
;
;     POKE 236,16      check 16 headers per statement, a fair starting point
;     POKE 236,0       off again
;
; a bigger count catches the damage closer to the statement that did it and
; runs slower. a whole sweep of a 500 line program takes 500/CHK_N statements,
; and the "Break in line" it reports is the line that was executing when the
; damage was noticed, not necessarily the one that caused it, so keep the
; count high enough that the two are close
;
; Y is restored because LIST calls the [CTRL-C] check with its line index in
; it. A and X are not, the stock CTRLC does not preserve them either

SENTINEL

.if DIAG_BUILT

; the block watch runs first and, when it is armed, instead of the chain walk.
; the two share zero page. it takes a copy of WCH_LEN bytes when it is armed
; and then compares a few of them per statement, round robin, so that it stays
; cheap enough to leave running without changing what the machine does
;
; it watches a block rather than a byte because the fault this is looking for
; lands wherever the stack pointer happens to be. a watch on one address misses
; a hit on the byte next to it, which is exactly what happened once

      LDA   WCH_ON            ; is the block watch armed?
      BEQ   @chain            ; no, try the chain sentinel

      STY   WCH_SAV           ; LIST calls this with its line index in Y
      BIT   WCH_ON            ; b7 set once the copy has been taken
      BMI   @compare

      LDY   #WCH_LEN-1        ; first look, so take the copy
@latch:
      LDA   (WCH_PTR),Y
      STA   WCH_COPY,Y
      DEY
      BPL   @latch

      STZ   WCH_IDX
      LDA   #$80
      TSB   WCH_ON            ; and note that it has been taken
      LDY   WCH_SAV
      RTS

@compare:
      LDY   WCH_IDX           ; pick up where the last statement left off
      LDA   (WCH_PTR),Y
      CMP   WCH_COPY,Y
      BNE   @wfail
      INY
      LDA   (WCH_PTR),Y
      CMP   WCH_COPY,Y
      BNE   @wfail
      INY
      LDA   (WCH_PTR),Y
      CMP   WCH_COPY,Y
      BNE   @wfail
      INY
      LDA   (WCH_PTR),Y
      CMP   WCH_COPY,Y
      BNE   @wfail
      INY
      TYA
      AND   #WCH_LEN-1        ; wrap the round robin
      STA   WCH_IDX
      LDY   WCH_SAV
      RTS

@wfail:
      JMP   @wbad             ; the report is out of branch range from here

.endif                        ; DIAG_BUILT

@chain:
.if SENT_BUILT
      LDA   CHK_N             ; is the chain sentinel switched on?
      BEQ   @done             ; no, nothing to do

      STA   CHK_CNT           ; headers to walk this time round

; editing the program moves the start of the variables, and it moves every
; line header after the edit with it, so a walk pointer from before the edit
; points at nothing in particular. spot the move and start a fresh sweep
; rather than report a line that is not there any more

      LDA   Svarl             ; has the program been edited under us?
      CMP   CHK_SVR
      BNE   @anchor

      LDA   Svarh
      CMP   CHK_SVR+1
      BEQ   @start            ; no, carry on where the last call left off

@anchor:
      LDA   Svarl             ; re-anchor and abandon the sweep in progress
      STA   CHK_SVR
      LDA   Svarh
      STA   CHK_SVR+1
      STZ   CHK_PTR+1         ; parked, the walk below starts it again

@start:
      PHY                     ; LIST needs its index back

@line:
      LDA   CHK_PTR+1         ; a parked pointer means start a fresh sweep
      BNE   @have

      JSR   @rewind
@have:
      LDY   #$01
      LDA   (CHK_PTR),Y       ; get link high byte
      BNE   @link             ; not the end of program marker

      JSR   @rewind           ; that was the marker, back to the first line
      BRA   @next

; the link has to stay below the variables, or the walk is being led out of
; the program by a header that is already damaged

; the report is out of branch range from here, so failures go through this

@toobad:
      JMP   @bad

@link:
      CMP   Svarh             ; compare link high byte with start of variables
      BCC   @order            ; clearly below, take it

      BNE   @toobad           ; clearly above, the link is damaged

      DEY                     ; same page, so compare the low bytes
      LDA   (CHK_PTR),Y
      CMP   Svarl
      BCS   @toobad           ; at or above the variables, damaged

; line numbers only ever increase along the chain

@order:
      LDY   #$03
      LDA   (CHK_PTR),Y       ; get this line number high byte
      CMP   CHK_NUM+1         ; compare with the previous line number
      BCC   @toobad           ; less, so out of order

      BNE   @keep             ; greater, so in order

      DEY                     ; high bytes matched, compare the low bytes
      LDA   (CHK_PTR),Y
      CMP   CHK_NUM
      BCC   @toobad           ; less, out of order

      BEQ   @toobad           ; equal, two lines cannot share a number

@keep:
      LDY   #$02              ; carry this line number into the next check
      LDA   (CHK_PTR),Y
      STA   CHK_NUM
      INY
      LDA   (CHK_PTR),Y
      STA   CHK_NUM+1

      LDY   #$00              ; and step the walk on to the next line
      LDA   (CHK_PTR),Y       ; get link low byte
      TAX
      INY
      LDA   (CHK_PTR),Y       ; get link high byte
      STX   CHK_PTR
      STA   CHK_PTR+1
@next:
      DEC   CHK_CNT           ; done enough for this statement?
      BNE   @line             ; no, do another header

      PLY                     ; give LIST its index back
.endif                        ; SENT_BUILT
@done:
      RTS

; start a sweep at the first line of the program, with a line number of zero
; behind it so that the first header always compares as in order

.if SENT_BUILT
@rewind:
      LDA   Smeml
      STA   CHK_PTR
      LDA   Smemh
      STA   CHK_PTR+1
      STZ   CHK_NUM
      STZ   CHK_NUM+1
      RTS

.endif                        ; SENT_BUILT

; take a copy of the zero page before anything else runs. by the time a human
; can type a MONITOR command the interpreter has taken a branch, and a branch
; reparks Baslnl ($AA/$AB) onto the damaged line all by itself, so a dump made
; by hand cannot tell the pointer that did the damage from the pointer the
; damage created. this one is made at the instant it is spotted
;
; the ring buffer page is the only 256 byte scratch there is. its contents do
; not matter now, and the caller empties the buffer so that the copy is not
; read back as type ahead

@snapzp:
      LDX   #$00
@snap:
      LDA   $00,X
      STA   INPUT_BUFFER,X
      INX
      BNE   @snap

      RTS

.if DIAG_BUILT

; the block watch fired. the stack holds only the return into CCHECK, because
; the watch runs before the chain walk saves anything

@wbad:
      JSR   @snapzp           ; freeze the zero page first

      PLA                     ; drop the return into CCHECK, the break below
      PLA                     ; leaves through LAB_1636 like [CTRL-C] does

      STZ   WCH_ON            ; one report is enough, disarm the watch
      LDA   READ_PTR          ; the ring buffer holds the copy now, so empty it
      STA   WRITE_PTR

      LDX   #$00              ; X, not Y - Y is the index of the byte that
@wmsg:                        ; changed and the report below needs it
      LDA   WCH_TXT,X
      BEQ   @wwhere
      JSR   CHROUT
      INX
      BNE   @wmsg             ; loop, branch always

@wwhere:
      TYA                     ; the address that changed is base + index
      CLC
      ADC   WCH_PTR
      TAX
      LDA   WCH_PTR+1
      ADC   #$00
      JSR   PRHEX
      TXA
      JSR   PRHEX
      JSR   SPACE
      LDA   WCH_COPY,Y        ; what it held when the watch was armed
      JSR   PRHEX
      JSR   SPACE
      LDA   (WCH_PTR),Y       ; and what is in it now
      JSR   PRHEX
      JMP   @dump

.endif                        ; DIAG_BUILT

.if SENT_BUILT

; the chain sentinel fired. the extra pull drops the index LIST left in Y

@bad:
      JSR   @snapzp           ; freeze the zero page first

      PLY                     ; drop the saved LIST index
      PLA                     ; and the return into CCHECK
      PLA

      STZ   CHK_N             ; one report is enough, switch the sentinel off
      LDA   READ_PTR          ; the ring buffer holds the copy now, so empty it
      STA   WRITE_PTR

      LDY   #$00
@msg:
      LDA   CHK_TXT,Y
      BEQ   @where
      JSR   CHROUT
      INY
      BNE   @msg              ; loop, branch always

@where:
      LDA   CHK_PTR+1         ; address of the header that failed
      JSR   PRHEX
      LDA   CHK_PTR
      JSR   PRHEX
      JSR   SPACE
      LDY   #$03              ; the line number that is out of order
      LDA   (CHK_PTR),Y
      JSR   PRHEX
      DEY
      LDA   (CHK_PTR),Y
      JSR   PRHEX
      JSR   SPACE
      LDA   CHK_NUM+1         ; and the line number before it
      JSR   PRHEX
      LDA   CHK_NUM
      JSR   PRHEX

.endif                        ; SENT_BUILT

; now the zero page as it was, in the shape the MONITOR dumps it

@dump:
      LDX   #$00
@zp:
      TXA
      AND   #$07              ; eight bytes to a line
      BNE   @byte

      JSR   CRLF
      LDA   #$00              ; the copy is always of page zero
      JSR   PRHEX
      TXA
      JSR   PRHEX
      LDA   #':'
      JSR   CHROUT
@byte:
      JSR   SPACE
      LDA   INPUT_BUFFER,X
      JSR   PRHEX
      INX
      BNE   @zp               ; loop, branch always

      LDA   #$03              ; [CTRL-C], so LAB_1636 prints "Break in line"
      JMP   LAB_1636          ; .. naming the line that was executing

.if SENT_BUILT
CHK_TXT
      .byte $0D,$0A,"*** CHAIN ",$00
.endif

.if DIAG_BUILT
WCH_TXT
      .byte $0D,$0A,"*** WATCH ",$00
.endif

CRLF
      LDA   #$0D
      JSR   CHROUT
      LDA   #$0A
      JMP   CHROUT

SPACE
      LDA   #' '
      JMP   CHROUT

; print A as two hex digits

PRHEX
      PHA                     ; save the byte
      LSR                     ; high nibble first
      LSR
      LSR
      LSR
      JSR   @digit
      PLA
@digit:
      AND   #$0F              ; mask off one nibble
      CMP   #$0A              ; is it A to F?
      BCC   @out              ; no, "0" to "9" is just an add

      ADC   #$06              ; carry is set, so this adds 7 in total
@out:
      ADC   #'0'
      JMP   CHROUT

; ---------------------------------------------------------------------------
.if DIAG_BUILT
; ---------------------------------------------------------------------------
; RAM bus stress test
;
; run it from WozMon with 8009R
;
; the line corruption this ROM's byte watch caught is a stray write: the data
; and the instruction were right, the address was not. both addresses it ever
; damaged are one address bit away from the only two regions of low RAM that
; anything writes often - $05EC is $01EC with A10 set, which is the stack, and
; $0B5F is $035F with A11 set, which is the serial receive buffer
;
; so this hammers those two pages and holds the whole of the rest of RAM as a
; guard, filled with a pattern computed from the address. anything that turns
; up in the guard arrived there by mistake
;
;     BUS TEST - ADDR WAS GOT PASS - RESET TO STOP
;     ...........
;     *** BUS 05EC EC 31 0042
;     ....
;
; the address is the whole story. exclusive-or it with $0400 and with $0800 and
; see which one lands in page one or page three - that is the address bit that
; let go. it puts the byte back and carries on, so one run collects the whole
; pattern rather than the first instance
;
; interrupts are off throughout, so nothing else can write to RAM and there is
; no way to type at it. reset the board to stop it, and take the [C]old start
; afterwards - this leaves the whole of RAM full of the guard pattern
;
; assumes the stock BE6502 memory map, 16K of RAM at $0000-$3FFF
;
; WHERE THIS CODE LIVES MATTERS. the fault it looks for is an address bit that
; was high for the instruction fetch failing to fall for the write that follows
; it, so a stress loop can only exercise the bits that are actually high at its
; own address. the first version of this sat at $AA93, where A10 is already low
; - the very bit that was slipping - and ran clean for thousands of passes
; while a BASIC program tripped over it in minutes. basic.cfg now pins it at
; $FC00, where A9 to A15 are all set, so every one of them has to fall on the
; way into page one

      .segment "BUSTST"       ; pinned at $FC00, see below and basic.cfg

GUARD_LO     = $02            ; first page held as guard
GUARD_HI     = $40            ; one past the last page held as guard
RING_PAGE    = $03            ; the serial buffer page, stressed rather than guarded

BUS_PTR      = $E8            ; guard walk pointer, low/high
BUS_CNT      = $EA            ; pass counter, low/high

BUSTEST
      SEI                     ; nothing else may write to RAM while this runs
      CLD
      LDX   #$FF              ; the test owns the stack
      TXS

      STZ   BUS_CNT
      STZ   BUS_CNT+1

      LDY   #$00
@banner:
      LDA   BUS_TXT,Y
      BEQ   @fill
      JSR   CHROUT
      INY
      BNE   @banner           ; loop, branch always

; fill the guard with a pattern computed from the address, so that a byte which
; has changed can be told apart from one that was never right

@fill:
      STZ   BUS_PTR
      LDA   #GUARD_LO
      STA   BUS_PTR+1
@fillpage:
      LDA   BUS_PTR+1
      CMP   #RING_PAGE        ; the serial buffer page is hammered below, so it
      BEQ   @fillnext         ; .. cannot also be held as guard

      LDY   #$00
@fill1:
      TYA
      EOR   BUS_PTR+1         ; pattern = address low byte EOR high byte
      STA   (BUS_PTR),Y
      INY
      BNE   @fill1            ; do the page

@fillnext:
      INC   BUS_PTR+1         ; then step to the next one
      LDA   BUS_PTR+1
      CMP   #GUARD_HI
      BNE   @fillpage

; hammer page one the way GOSUB does, a read followed by a push, with the reads
; alternating between the top of RAM and zero page so that most of the address
; bus changes on either side of every write

@pass:
      LDX   #$FF
      TXS
      LDY   #$00
@push:
      LDA   $3F00,Y           ; read high up the address bus ..
      PHA                     ; .. then write to page one
      JSR   @spin             ; a JSR/RTS pair, for the pushes GOSUB makes
                              ; through its own nested calls
      LDA   $0080,Y           ; and a low read before the next write
      PHA
      INY
      BNE   @push             ; 512 pushes, which wraps right through the page

      LDX   #$FF              ; the pushes wrapped the stack, put it back
      TXS

      LDY   #$00              ; now hammer the serial buffer page
@ring:
      TYA
      EOR   #$5A
      STA   $0300,Y
      INY
      BNE   @ring

; and check that nothing landed anywhere it should not have

      STZ   BUS_PTR
      LDA   #GUARD_LO
      STA   BUS_PTR+1
@checkpage:
      LDA   BUS_PTR+1
      CMP   #RING_PAGE        ; skip the page the stress above writes
      BEQ   @checknext

      LDY   #$00
@check:
      TYA
      EOR   BUS_PTR+1         ; what this byte should hold
      CMP   (BUS_PTR),Y
      BNE   @stray
@next:
      INY
      BNE   @check            ; do the page

@checknext:
      INC   BUS_PTR+1         ; then step to the next one
      LDA   BUS_PTR+1
      CMP   #GUARD_HI
      BNE   @checkpage

      INC   BUS_CNT           ; one more clean pass
      BNE   @dot
      INC   BUS_CNT+1
@dot:
      LDA   #'.'              ; something to watch
      JSR   CHROUT
      BRA   @pass

@spin:
      RTS

; report a byte of the guard that changed, put it back, and carry on

@stray:
      JSR   CRLF
      LDX   #$00
@smsg:
      LDA   BUS_TX2,X
      BEQ   @swhere
      JSR   CHROUT
      INX
      BNE   @smsg             ; loop, branch always

@swhere:
      LDA   BUS_PTR+1         ; the address that changed
      JSR   PRHEX
      TYA
      JSR   PRHEX
      JSR   SPACE
      TYA                     ; what it should have held
      EOR   BUS_PTR+1
      JSR   PRHEX
      JSR   SPACE
      LDA   (BUS_PTR),Y       ; and what it does hold
      JSR   PRHEX
      JSR   SPACE
      LDA   BUS_CNT+1         ; how many clean passes came before it
      JSR   PRHEX
      LDA   BUS_CNT
      JSR   PRHEX

      TYA                     ; put it back so that one run collects the whole
      EOR   BUS_PTR+1         ; pattern rather than stopping at the first
      STA   (BUS_PTR),Y
      BRA   @next

BUS_TXT
      .byte $0D,$0A,"BUS TEST - ADDR WAS GOT PASS - RESET TO STOP",$0D,$0A,$00

BUS_TX2
      .byte "*** BUS ",$00

      .segment "CODE"

.endif                        ; DIAG_BUILT

.endif                        ; TOOLS_BUILT

; vector tables

LAB_vec
      .word CHRIN             ; byte in from ACIA receive buffer
      .word CHROUT            ; byte out to ACIA
      .word no_load           ; null load vector for EhBASIC
      .word no_save           ; null save vector for EhBASIC

; EhBASIC IRQ support

IRQ_CODE
      PHA                     ; save A
      LDA   IrqBase           ; get the IRQ flag byte
      LSR                     ; shift the set b7 to b6, and on down ...
      ORA   IrqBase           ; OR the original back in
      STA   IrqBase           ; save the new IRQ flag byte
      PLA                     ; restore A
      RTI

; EhBASIC NMI support

NMI_CODE
      PHA                     ; save A
      LDA   NmiBase           ; get the NMI flag byte
      LSR                     ; shift the set b7 to b6, and on down ...
      ORA   NmiBase           ; OR the original back in
      STA   NmiBase           ; save the new NMI flag byte
      PLA                     ; restore A
      RTI

END_CODE

LAB_mess
      .byte $0D,$0A,"6502 EhBASIC [C]old/[W]arm ?",$00
                              ; sign on string

; hardware interrupt handler. this owns the IRQ vector rather than EhBASIC so
; that received bytes reach the ring buffer. anything that is not the ACIA is
; passed on to EhBASIC's own handler in RAM, which is what makes ON IRQ work
;
; this must sit outside LAB_vec..END_CODE, that block gets copied to page 2

ACIA_IRQ
      PHA                     ; save A
      PHX                     ; save X, WRITE_BUFFER uses it
      LDA   ACIA_STATUS       ; get ACIA status, this clears its IRQ flag
      BPL   @chain            ; b7 clear, the ACIA did not raise this one

      AND   #$08              ; mask rx buffer status flag
      BEQ   @done             ; ACIA interrupt but no byte waiting

      JSR   BUFFER_SIZE       ; is there room for it?
      CMP   #BUF_FULL
      BEQ   @overflow         ; no, drop it rather than lap the read pointer

      LDA   ACIA_DATA         ; get byte from ACIA data port

; [CTRL-C] is noted here rather than by pulling bytes out of the buffer later,
; which is what the stock check does. it still goes into the buffer so that
; GET and INPUT can see it, the flag is only how CCHECK finds out about it

      CMP   #$03              ; [CTRL-C]?
      BNE   @buffer           ; no, just buffer it

      STA   BRK_FLAG          ; flag the break, A is non zero so the flag is set
@buffer:
      JSR   WRITE_BUFFER      ; add it to the ring buffer
      JSR   BUFFER_SIZE       ; how full are we now?
      CMP   #HIGH_WATER
      BCC   @done             ; still room, leave the host alone

      LDA   #$01
      ORA   PORTA             ; set PA0 ..
      STA   PORTA             ; .. tell the host to stop sending
@done:
      PLX                     ; restore X
      PLA                     ; restore A
      RTI

; the buffer is already full, so this byte is lost either way. dropping it
; keeps the buffer coherent, where overwriting would lap the read pointer and
; corrupt everything still queued behind it. only reachable when the host is
; ignoring PA0, either by choice or because the CTS wire is not fitted

@overflow:
      LDA   ACIA_DATA         ; discard it, the read is still needed to clear
                              ; the receiver data register full flag
      BRA   @done

@chain:
      PLX                     ; restore X
      PLA                     ; restore A
      JMP   IRQ_vec           ; hand to EhBASIC's RAM handler, it does the RTI

; system vectors

      .segment "VECTORS"

      .word NMI_vec           ; NMI vector
      .word RES_vec           ; RESET vector
      .word ACIA_IRQ          ; IRQ vector

      .end RES_vec            ; set start at reset vector
      
