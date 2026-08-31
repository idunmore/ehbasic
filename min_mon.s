; minimal monitor for EhBASIC and 6502 simulator V1.05
; tabs converted to space, tabwidth=6

; To run EhBASIC on the simulator load and assemble [F7] this file, start the simulator
; running [F6] then start the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

; ** Conditionally Included Features **

; The LCD extensions default to being INCLUDED, so a missing LCD_ENABLE means
; yes, not no. ca65 resolves the .if as it goes, so this has to come before the 
; first test of it, both here and in basic.s where it guards the LCD
; keywords' table entries

.ifdef LCD_ENABLE
LCD_BUILT    = LCD_ENABLE
.else
LCD_BUILT    = 1
.endif

; The inline Assembler defaults to in on the same terms, and for the same
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

; The MONITOR command body lives in custom_commands.s. importing it here,
; ahead of the include, keeps the edits to basic.s down to table entries

      .import LAB_MONITOR

; RENUMBER lives in custom_commands.s too, and is always built. basic.s names
; it in LAB_CTBL, so it has to be imported ahead of the include as well

      .import LAB_RENUMBER

; The LCD driver and the LCD keyword bodies also live in custom_commands.s.
; basic.s names the command entry points in LAB_CTBL and LCDINIT is called from
; RES_vec below, so both have to be imported ahead of the include

.if LCD_BUILT
      .import LCDINIT
      .import LCDCMD, LCDPRINT, LCDCGCHRS, LCDCLS, LCDHOME
      .import LCDCURPOS, LCDDDRAM, LCDCGRAM, LCDCGBYTE
      .import LCDCURENABLE, LCDCURBLINK, LCDMOVECUR, LCDSCROLL
.endif

; The inline assembler's command bodies live in assembler.s and disasm.s.
; basic.s names all five entry points in LAB_CTBL and LAB_FTBL, so they
; must all be imported ahead of the include as well

.if ASM_BUILT
      .import LAB_ASM, LAB_ENDASM, LAB_ASSEMBLE, LAB_DASM, LAB_SYM
.endif

; CHRIN and CHROUT are the serial primitives, wozmon.s uses them rather than
; carrying its own copy of the 65C51 transmit bug workaround

      .export CHRIN, CHROUT

; Set by the interrupt handler when a [CTRL-C] comes in, tested by CCHECK
; below. it has to be equated ahead of the include so that basic.s assembles
; its one reference to it as zero page

BRK_FLAG     = $E7            ; [CTRL-C] seen by the interrupt handler

; The assembler's "image is good" flag. basic.s clears it from three places -
; a program line edit, NEW and CLEAR - so it has to be equated ahead of the
; include, the same way BRK_FLAG is. The rest of the assembler's zero page is
; declared in assembler.s and starts at $2D, immediately above this

.if ASM_BUILT
ASM_FLG      = $2C            ; $00 no image, $80 image assembled and good
      .exportzp ASM_FLG
.endif

; Build time options, set from the Makefile
;
;
;   LCD_ENABLE     Inverted; set to 0 to leave the HD44780 LCD extensions OUT.
;                  It is always passed by the Makefile and defaults to 1, so
;                  the stock ROM does carry them. Tested via LCD_BUILT, which
;                  resolved earlier in this file

      .include "basic.s"

; The LCD command bodies in custom_commands.s are a port of my code written for
; Microsoft BASIC, so they need EhBASIC's parameter fetching. These have to be
; exported from here rather than from basic.s because this is the unit that
; includes it. See the table at the top of custom_commands.s for what each one
; stood in for on the MS-BASIC side

; The assembler in assembler.s needs a good deal of the same machinery, so the
; parts both want are exported once, under a flag that is set when either is
; built. Exporting the same symbol twice is an error, hence the split.

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
; The zero page names are the program and memory pointers RENUMBER walks and
; rewrites. The TK_ ones are byte equates, hence .exportzp, the same way the
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

      .segment "CODE"         ; pretend this is in a 1/8K ROM

; Reset vector points here

RES_vec
      CLD                     ; clear decimal mode
      LDX   #$FF              ; empty stack
      TXS                     ; set the stack
      JSR   ACIAsetup         ; init ring buffer and ACIA (receiver IRQ enabled)
.if LCD_BUILT
      JSR   LCDINIT           ; bring the LCD up. port B, so it does not collide
                              ; with the flow control bit ACIAsetup put on port A
.endif

; Set up vectors and interrupt code, copy them to page 2

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
; This replaces the stock CTRLC, which scans the input device itself and keeps
; whatever it finds in ccbyte under a countdown that only GET ever reads. with
; input buffered that reliably swallows a typed or pasted character every time
; a direct command runs or a program passes a statement boundary. The received
; byte is examined by the interrupt handler instead, so nothing is taken out of
; the input stream here and a [CTRL-C] is still seen even with type ahead
; queued up behind it
;
; Falls through to EhBASIC's own ON IRQ/ON NMI checks, exactly as CTRLC does

CCHECK
      LDA   ccflag            ; get [CTRL-C] check flag
      BNE   @nobreak          ; exit if inhibited

      LDA   BRK_FLAG          ; has the interrupt handler seen a [CTRL-C]?
      BEQ   @nobreak          ; no, nothing to do

      STZ   BRK_FLAG          ; take it, one [CTRL-C] is one break
      LDA   #$03              ; [CTRL-C], LAB_1636 tests for it
      JMP   LAB_1636          ; go stop the program

@nobreak:
      JMP   LAB_FBA2          ; go do the interrupt checks and return

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

; Hardware interrupt handler. this owns the IRQ vector rather than EhBASIC so
; that received bytes reach the ring buffer. anything that is not the ACIA is
; passed on to EhBASIC's own handler in RAM, which is what makes ON IRQ work
;
; This must sit outside LAB_vec..END_CODE, that block gets copied to page 2

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

; The buffer is already full, so this byte is lost either way. dropping it
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
