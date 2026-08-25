; Command bodies for the keywords this project adds to EhBASIC.
;
; The token tables themselves have to live in basic.s (TK_* equates, LAB_CTBL,
; TAB_ASCx and LAB_KEYT), so the edits there are kept to table entries and the
; code that runs sits here.

      .export LAB_MONITOR, LAB_RENUMBER
      .import WOZMON, CHROUT

; the LCD extensions default to in, so a missing LCD_ENABLE means yes, not no.
; this is a separate assembly unit from min_mon.s, so it works the flag out for
; itself rather than inheriting it. the two must agree, which they do because
; the Makefile passes the same -D to both

.ifdef LCD_ENABLE
LCD_BUILT = LCD_ENABLE
.else
LCD_BUILT = 1
.endif

; the inline assembler goes the same way. RENUMBER only wants to know whether
; it is there, so that it can mark the assembled image stale the way every
; other edit to the program does

.ifdef ASM_ENABLE
ASM_BUILT = ASM_ENABLE
.else
ASM_BUILT = 1
.endif

; what RENUMBER borrows from EhBASIC. all of it is exported unconditionally
; from min_mon.s, below its include of basic.s, because RENUMBER is not an
; optional part of the ROM the way the LCD and the assembler are
;
;   LAB_GBYT   scan at the execute pointer, Z set at end of statement
;   LAB_IGBY   increment the execute pointer and scan
;   LAB_GFPN   read a line number, ASCII digits to Itempl/h, caps at 63999
;   LAB_SNER   syntax error and warm start
;   LAB_XERR   raise error number X and warm start
;   LAB_11CF   open up space in memory, "Out of memory" if it will not fit
;   LAB_147A   the body of CLEAR, resets variables and string space
;   LAB_1477   reset execution, clear variables, flush the stack
;   LAB_1274   the warm start: "Ready" and wait for the next command
;   LAB_18C3   print a null terminated string from AY
;   LAB_295E   print XA as an unsigned integer, which is how a line number
;              gets printed everywhere else
;
;   Smeml      start of the program        Svarl   end of it, start of vars
;   Itempl     where LAB_GFPN leaves a number, and RENUMBER's own scratch
;   Clineh     $FF in direct mode, which is the only mode RENUMBER runs in
;   Ostrtl     block move source start     Obendl  source end
;   Nbendl     block move destination end
;
; the TK_ names are the keywords a line number can follow

      .import LAB_GFPN, LAB_SNER, LAB_XERR, LAB_11CF
      .import LAB_147A, LAB_1477, LAB_1274, LAB_18C3, LAB_295E
      .importzp LAB_IGBY, LAB_GBYT
      .importzp Smeml, Svarl, Itempl, Clineh
      .importzp Ostrtl, Obendl, Nbendl
      .importzp TK_GOTO, TK_GOSUB, TK_THEN, TK_ELSE, TK_LIST
      .importzp TK_RUN, TK_RESTORE, TK_REM, TK_DATA, TK_MINUS

.if ASM_BUILT
      .importzp ASM_FLG
.endif

.if LCD_BUILT

; the LCD driver and the bodies of the LCD keywords. LCDINIT is called from
; RES_vec in min_mon.s, everything else is reached through LAB_CTBL. LCDDDRAM
; and LCDCGCHRS are second names for LCDCURPOS and LCDPRINT, they are exported
; so that basic.s can give each one its own token pointing at the same code

      .export LCDINIT
      .export LCDCMD, LCDPRINT, LCDCGCHRS, LCDCLS, LCDHOME
      .export LCDCURPOS, LCDDDRAM, LCDCGRAM, LCDCGBYTE
      .export LCDCURENABLE, LCDCURBLINK, LCDMOVECUR, LCDSCROLL

; EhBASIC internals, exported from min_mon.s below its include of basic.s.
; the MS-BASIC routine each one stands in for is named because these command
; bodies are a port of imdlabs_lcd.s, which was written against MS-BASIC
;
;   LAB_GTBY   get byte parameter, result in X      (GETBYT)
;   LAB_EVNM   evaluate numeric expression          (FRMNUM)
;   LAB_EVIR   FAC1 float to fixed, no sign check   (AYINT)
;   LAB_EVEX   evaluate any expression              (FRMEVL)
;   LAB_296E   convert FAC1 to a string, AY = ptr   (FOUT)
;   LAB_20AE   build a descriptor from the AY string (STRLIT)
;   LAB_22B6   pop a descriptor, A = length         (FREFAC)
;   LAB_IGBY   increment the execute pointer and scan
;   LAB_GBYT   scan at the execute pointer, Z set at end of statement
;   Dtypef     data type flag, $FF = string         (VALTYP)
;   FAC1_2     FAC1 mantissa2, integer high byte    (FAC+3)
;   FAC1_3     FAC1 mantissa3, integer low byte     (FAC+4)
;   ut1_pl     utility pointer 1, set by LAB_22B6

      .import LAB_GTBY, LAB_EVNM, LAB_EVIR, LAB_EVEX
      .import LAB_296E, LAB_20AE, LAB_22B6

; LAB_IGBY and LAB_GBYT are code EhBASIC copies into page zero at cold start,
; so they are zero page symbols even though every call to them is a JSR, which
; has no zero page mode and assembles as absolute either way. both are in the
; unconditional import block above, RENUMBER wants them too

      .importzp Dtypef, FAC1_2, FAC1_3, ut1_pl

.endif

      .segment "CODE"

; MONITOR     hand control to WozMon at $FE00.
;
; This does not return. The way back is 8000R, which signs on and offers the
; [C]old/[W]arm prompt again, or 8006R to go straight to a warm start with the
; BASIC program still in memory. Neither WozMon nor this routine disturbs the
; program, so either route leaves it listable and runnable.
;
; Reached through EhBASIC's RTS vector dispatch, so A, X and Y are all free.
; Whatever it leaves on the stack does not matter, both return paths reset it.

LAB_MONITOR
      LDY   #$00              ; clear message index
LAB_MONMSG
      LDA   LAB_MONTXT,Y      ; get byte from the banner
      BEQ   LAB_MONGO         ; exit loop if done

      JSR   CHROUT            ; output character
      INY                     ; increment index
      BNE   LAB_MONMSG        ; loop, branch always

LAB_MONGO
      JMP   WOZMON            ; hand over, WozMon signs on with its own "\"

; the trailing CR/LF puts WozMon's "\" on the line below this message, it is
; printed where the cursor is left

LAB_MONTXT
      .byte $0D,$0A,"WozMon - 8000R returns to EhBASIC",$0D,$0A,$00

; ---------------------------------------------------------------------------
; RENUMBER [new [, inc [, old]]]
;
; Renumber the stored program and fix up every line number it refers to.
;
;   new   the first new line number, 10 if it is not given
;   inc   the step between new line numbers, 10 if it is not given
;   old   the first existing line number to renumber, the start of the
;         program if it is not given
;
; The arguments are strictly positional - inc cannot be given without new, and
; old cannot be given without both. RENUMBER 1000,10,100 renumbers the lines
; from 100 upwards to start at 1000 and step by 10, and leaves everything
; below 100 exactly as it was. Plain RENUMBER does the lot, 10, 20, 30 ..
;
; References are fixed up after GOTO, GOSUB, THEN, ELSE, RUN, RESTORE and
; LIST, and in the comma list of an ON .. GOTO or ON .. GOSUB. IF .. GOTO n
; needs nothing extra, it is the GOTO case. A reference that names no line is
; reported and left pointing where it was.
;
; Direct mode only. Renumbering a running program would move the code out from
; under the execute pointer and the GOSUB and FOR structures on the stack.
;
; Variables are cleared, and ON IRQ and ON NMI are disabled, the way they are
; by a warm start.
;
; ---------------------------------------------------------------------------
; Why this takes four passes
;
; Line numbers live in the program in two quite different forms. The one in
; the line header at offsets 2 and 3 is a binary word, and rewriting it costs
; nothing. The one after GOTO is plain ASCII digits in the crunched text,
; re-read at run time by LAB_GFPN, because the tokenizer passes "0" to "9"
; straight through. So GOTO 90 becoming GOTO 1000 makes its line two bytes
; longer, and GOTO 1000 becoming GOTO 10 makes it two bytes shorter.
;
; Working out what a reference becomes means looking its old number up among
; the line headers, so the program has to still be on its old numbers, in one
; piece, while that is going on. That rules out doing the lookups during a
; pass that is also shuffling the text about - the copy would be eating the
; very headers the lookups need to read.
;
; So the moving and the looking up are kept apart. Every reference is first
; widened to a fixed five digits, which is the most a line number can take.
; With every reference the same width the numbers can be swapped over without
; the program changing size at all, which is the pass that does the lookups.
; A last pass takes the padding back off.
;
;   1  measure   how much wider does making every reference five digits make
;                the program?
;   2  widen     reserve that, shift the program up into it, and copy it back
;                down padding every reference out to five digits
;   3  map       nothing moves. read each five digit reference, look its line
;                up, and write the new number back in the same five digits.
;                the headers are still on their old numbers, which is what
;                makes the lookups work
;   4  trim      copy back down dropping the padding, and put the new numbers
;                in the line headers on the way past
;
; then the chain of next line pointers is rebuilt and the variables cleared,
; exactly as they are after a line is typed in.
;
; All four passes are the same code. RN_FLG bits 0 and 1 say which one is
; running, and it only reaches as far as RN_PUT and RN_NUM.
; ---------------------------------------------------------------------------

; the highest line number EhBASIC will accept. LAB_GFPN stops at 63999, so a
; renumber that would generate anything above it has to be refused, and five
; digits is the most any line number can need

RN_LMAX      = 63999
RN_WIDTH     = 5

; "RENUMBER Error". this has to match LAB_BAER in basic.s, where it sits ahead
; of the assembler's codes precisely so that it is $24 in every build

ERRNUM_RN    = $24

; zero page.
;
; $13-$23 is what is left of EhBASIC's unused $13-$5A once wozmon.s has taken
; $24-$2B and assembler.s everything from $2C to $58. Nothing here survives
; the command, it is all working storage.

RN_NEW       = $13            ; first new line number, low/high
RN_INC       = $15            ; step between new line numbers, low/high
RN_OLD       = $17            ; first old line number to renumber, low/high
RN_LNO       = $19            ; new number of the line being walked, low/high
RN_MPT       = $1B            ; RN_MAP's own line walk pointer, low/high
RN_CUR       = $1D            ; the number that walk has got to, low/high
RN_SRC       = $1F            ; the program being read, low/high
RN_DST       = $21            ; the program being written, low/high
RN_FLG       = $23            ; see below

; the measuring pass has nothing to write, so its two destination bytes count
; up how much room the widening pass is going to need instead

RN_GRW       = RN_DST         ; bytes the widening adds, low/high

; RN_FLG
;
;   b7     inside a quoted string
;   b6     inside a DATA statement
;   b5     the walk has reached the lines that are being renumbered
;   b4     a line below RN_OLD was seen                        (RN_CHK only)
;   b1,b0  which pass is running
;
; b7 and b6 are where they are so that one BIT RN_FLG tests both

RN_FQUO      = %10000000
RN_FDAT      = %01000000
RN_FRUN      = %00100000
RN_FKEP      = %00010000
RN_FPASS     = %00000011

RN_MEAS      = 0              ; measure what the widening costs
RN_WIDE      = 1              ; pad every reference out to five digits
RN_MAPP      = 2              ; swap old numbers for new ones, same width
RN_TRIM      = 3              ; take the padding off, and do the headers

; ---------------------------------------------------------------------------

LAB_RENUMBER
      LDY   Clineh            ; $FF only in direct mode
      INY
      BEQ   rn_direct

      JMP   rn_err            ; inside a program, which is not allowed

rn_direct
      LDA   #10               ; RENUMBER on its own is RENUMBER 10,10,0
      STA   RN_NEW
      STA   RN_INC
      STZ   RN_NEW+1
      STZ   RN_INC+1
      STZ   RN_OLD
      STZ   RN_OLD+1
      STZ   RN_FLG

      JSR   RN_ARGS           ; read whatever was given, over those defaults
      JSR   RN_CHK            ; and check it against the program
      BCS   rn_go

      RTS                     ; no line at or above the one the third argument
                              ; named, so there is nothing here to do. nothing
                              ; has been touched and the stack is still as the
                              ; dispatcher left it, so a plain RTS will do

; clear the variables now rather than at the end. the block move below writes
; over the bottom of the variable area, and an "Undefined" report builds a
; string descriptor, which is not a thing to do with a half wrecked variable
; table underneath it.
;
; LAB_147A ends in LAB_1491, which flushes the stack and forges its caller's
; return address back onto it. that is fine here, it is called from the top
; level of RENUMBER and the interpreter's own return address is the one that
; gets forged - but from this point on RENUMBER must leave by a JMP and never
; by an RTS

rn_go
      JSR   LAB_147A          ; the body of CLEAR

; pass 1, measure. nothing is written, so RN_DST counts the widening instead

      JSR   RN_START
      STZ   RN_GRW
      STZ   RN_GRW+1
      LDA   #RN_MEAS
      JSR   RN_MODE
      JSR   RN_PASS

; open up what that came to and shift the program up into it, so that pass 2
; always has the text it is reading ahead of where it is writing

      LDA   RN_GRW
      ORA   RN_GRW+1
      BEQ   rn_no_move        ; every reference is five digits already

      LDA   Smeml
      STA   Ostrtl
      LDA   Smeml+1
      STA   Ostrtl+1
      LDA   Svarl
      STA   Obendl
      LDA   Svarl+1
      STA   Obendl+1

      CLC
      LDA   Svarl
      ADC   RN_GRW
      STA   Nbendl
      LDA   Svarl+1
      ADC   RN_GRW+1
      STA   Nbendl+1
      TAY                     ; LAB_11CF wants the address to check in AY
      LDA   Nbendl
      JSR   LAB_11CF          ; check there is room, "Out of memory" if not,
                              ; then move the program up

rn_no_move

; pass 2, widen. the source is wherever the move above left the program, the
; destination is where it used to be

      CLC
      LDA   Smeml
      ADC   RN_GRW
      STA   RN_SRC
      LDA   Smeml+1
      ADC   RN_GRW+1
      STA   RN_SRC+1
      LDA   Smeml
      STA   RN_DST
      LDA   Smeml+1
      STA   RN_DST+1
      LDA   #RN_WIDE
      JSR   RN_MODE
      JSR   RN_PASS
      JSR   RN_ENDP           ; [EOT], Svarl, and the array pointers with it
      JSR   RN_CHAIN          ; the block move left every next line pointer
                              ; naming the address its line used to be at, and
                              ; the pass below wants to walk them

; pass 3, map. every reference is five digits wide now, and the new number
; goes back in the same five, so nothing moves and the line headers stay on
; their old numbers for RN_MAP to look up

      JSR   RN_START
      LDA   Smeml
      STA   RN_DST
      LDA   Smeml+1
      STA   RN_DST+1
      LDA   #RN_MAPP
      JSR   RN_MODE
      JSR   RN_PASS

; pass 4, trim. take the padding back off, and put the new numbers into the
; line headers on the way past

      JSR   RN_START
      LDA   Smeml
      STA   RN_DST
      LDA   Smeml+1
      STA   RN_DST+1
      LDA   #RN_TRIM
      JSR   RN_MODE
      JSR   RN_PASS
      JSR   RN_ENDP

.if ASM_BUILT
      STZ   ASM_FLG           ; the assembled image is stale, every line
                              ; number it was built against has moved
.endif

      JSR   LAB_1477          ; reset execution, clear variables, flush stack
      JSR   RN_CHAIN          ; the trim pass moved every line again

; out through the warm start rather than straight back to the input loop, so
; that RENUMBER signs off with "Ready" the way LIST and NEW do - they get
; there by returning to the interpreter, which finds the end of an immediate
; mode line and jumps here itself (LAB_1651 in basic.s). RENUMBER cannot take
; that route, LAB_147A above flushed the stack out from under it.
;
; the warm start also clears the ON IRQ and ON NMI enables, which matters more
; here than it does after a LIST. LAB_SIRQ stores the address of the line it
; was given, not its number, and every line has just moved

      JMP   LAB_1274

rn_err
      LDX   #ERRNUM_RN
      JMP   LAB_XERR          ; "RENUMBER Error" and warm start

; ---------------------------------------------------------------------------
; RN_CHAIN  rebuild the chain of next line pointers.
;
; They hold absolute addresses, so every one of them is wrong the moment a
; pass moves the program. This is the loop from LAB_1319 in basic.s with
; RN_SRC in place of ut1_pl.
; ---------------------------------------------------------------------------

RN_CHAIN
      JSR   RN_START
rn_link
      LDY   #$01
      LDA   (RN_SRC),Y        ; next line pointer high byte, $00 is [EOT]
      BEQ   rn_link_done

      LDY   #$04              ; the first byte of the text is never [EOL],
                              ; empty lines are deleted rather than stored
rn_link_lp
      INY
      LDA   (RN_SRC),Y
      BNE   rn_link_lp

      SEC                     ; +1 to step past the [EOL]
      TYA
      ADC   RN_SRC
      TAX                     ; keep the next line's address
      LDY   #$00
      STA   (RN_SRC),Y        ; this line's next line pointer, low byte
      LDA   #$00
      ADC   RN_SRC+1          ; carry is still the one from the add above
      INY
      STA   (RN_SRC),Y        ; and its high byte
      STX   RN_SRC
      STA   RN_SRC+1
      BRA   rn_link

rn_link_done
      RTS

; ---------------------------------------------------------------------------
; RN_START  point RN_SRC at the start of the program.
; RN_MODE   start a pass. A is which one, and the quote, DATA and renumbered
;           run bits all start clear.
; RN_ENDP   finish a pass that changed the length of the program: put the two
;           byte [EOT] on the end, hand the end to Svarl, and take the array
;           and string pointers with it.
; ---------------------------------------------------------------------------

RN_START
      LDA   Smeml
      STA   RN_SRC
      LDA   Smeml+1
      STA   RN_SRC+1
      RTS

RN_MODE
      STA   RN_FLG
      RTS

RN_ENDP
      LDA   #$00
      JSR   RN_PUT
      LDA   #$00
      JSR   RN_PUT
      LDA   RN_DST
      STA   Svarl
      LDA   RN_DST+1
      STA   Svarl+1
      JMP   LAB_147A          ; put the array and string pointers back on the
                              ; new end of the program

; ---------------------------------------------------------------------------
; RN_ARGS  read the arguments over the defaults already in RN_NEW, RN_INC and
;          RN_OLD.
;
; They are strictly positional. Missing ones keep their default, but a missing
; one cannot be skipped over - RENUMBER 10,,5 is a syntax error, not a step of
; ten and a start of five.
; ---------------------------------------------------------------------------

RN_ARGS
      JSR   LAB_GBYT          ; anything following the keyword?
      BEQ   rn_args_end       ; no, take all three defaults

      BCS   rn_args_syn       ; something that is not a digit

      JSR   LAB_GFPN          ; the first new line number
      LDA   Itempl
      STA   RN_NEW
      LDA   Itempl+1
      STA   RN_NEW+1

      JSR   LAB_GBYT          ; is there a second argument?
      BEQ   rn_args_end

      CMP   #','
      BNE   rn_args_syn

      JSR   LAB_IGBY          ; step over the ","
      BCS   rn_args_syn

      JSR   LAB_GFPN          ; the increment
      LDA   Itempl
      STA   RN_INC
      LDA   Itempl+1
      STA   RN_INC+1

      JSR   LAB_GBYT          ; is there a third argument?
      BEQ   rn_args_end

      CMP   #','
      BNE   rn_args_syn

      JSR   LAB_IGBY          ; step over the ","
      BCS   rn_args_syn

      JSR   LAB_GFPN          ; the first old line number to renumber
      LDA   Itempl
      STA   RN_OLD
      LDA   Itempl+1
      STA   RN_OLD+1

      JSR   LAB_GBYT          ; and that should be the end of the statement
      BNE   rn_args_syn

rn_args_end
      RTS

rn_args_syn
      JMP   LAB_SNER          ; syntax error and warm start

; ---------------------------------------------------------------------------
; RN_CHK   check the arguments against the program.
;
; Everything that can be wrong with them is caught here, before anything has
; been moved. Returns carry clear if there is no line at or above the third
; argument, in which case there is nothing to renumber.
; ---------------------------------------------------------------------------

RN_CHK
      LDA   RN_INC
      ORA   RN_INC+1
      BNE   rn_chk_walk

      JMP   rn_err            ; a step of zero would number every line the same

rn_chk_walk
      LDA   Smeml
      STA   RN_MPT
      LDA   Smeml+1
      STA   RN_MPT+1
      LDA   RN_FLG
      AND   #<~RN_FKEP
      STA   RN_FLG            ; no line below RN_OLD seen yet

; walk the lines that keep their numbers, holding on to the last one

rn_chk_low
      LDY   #$01
      LDA   (RN_MPT),Y
      BEQ   rn_chk_none       ; ran out of program without reaching RN_OLD

      LDY   #$03
      LDA   (RN_MPT),Y        ; this line's number, high byte
      CMP   RN_OLD+1
      BCC   rn_chk_keep
      BNE   rn_chk_first

      DEY
      LDA   (RN_MPT),Y        ; low byte
      CMP   RN_OLD
      BCS   rn_chk_first

rn_chk_keep
      LDY   #$02              ; remember it, the first new number has to clear
      LDA   (RN_MPT),Y        ; whatever the last kept line was
      STA   RN_CUR
      INY
      LDA   (RN_MPT),Y
      STA   RN_CUR+1
      LDA   RN_FLG
      ORA   #RN_FKEP
      STA   RN_FLG
      JSR   RN_NXTM
      BRA   rn_chk_low

; RN_MPT is the first line that gets a new number

rn_chk_first
      LDA   RN_FLG
      AND   #RN_FKEP
      BEQ   rn_chk_range      ; nothing below it to collide with

      LDA   RN_CUR            ; is the last kept number below the first new
      CMP   RN_NEW            ; one? it has to be, or the renumbered lines
      LDA   RN_CUR+1          ; would land on top of the kept ones
      SBC   RN_NEW+1
      BCC   rn_chk_range

      JMP   rn_err            ; new <= kept, so the two runs would collide

; generate the new numbers and check they stay inside a line number

rn_chk_range
      LDA   RN_NEW
      STA   RN_CUR
      LDA   RN_NEW+1
      STA   RN_CUR+1
rn_chk_lp
      LDA   RN_CUR+1
      CMP   #>RN_LMAX
      BCC   rn_chk_ok
      BNE   rn_chk_over

      LDA   RN_CUR
      CMP   #<RN_LMAX
      BEQ   rn_chk_ok
      BCS   rn_chk_over

rn_chk_ok
      JSR   RN_NXTM           ; is there another line after this one?
      LDY   #$01
      LDA   (RN_MPT),Y
      BEQ   rn_chk_done

      CLC
      LDA   RN_CUR
      ADC   RN_INC
      STA   RN_CUR
      LDA   RN_CUR+1
      ADC   RN_INC+1
      STA   RN_CUR+1
      BCC   rn_chk_lp         ; straight off the top of sixteen bits if not

rn_chk_over
      JMP   rn_err

rn_chk_done
      SEC                     ; there is work to do
      RTS

rn_chk_none
      CLC                     ; there is not
      RTS

; ---------------------------------------------------------------------------
; RN_PASS  walk the program from RN_SRC to RN_DST, doing whatever the pass in
;          RN_FLG says at each line number reference.
; ---------------------------------------------------------------------------

RN_PASS
      LDY   #$01
      LDA   (RN_SRC),Y        ; next line pointer high byte, $00 is [EOT]
      BNE   rn_pass_go

      RTS

rn_pass_go
      LDY   #$02              ; this line's number as it stands
      LDA   (RN_SRC),Y
      STA   Itempl
      INY
      LDA   (RN_SRC),Y
      STA   Itempl+1

      LDA   Itempl+1          ; is it one of the lines being renumbered?
      CMP   RN_OLD+1
      BCC   rn_pass_low
      BNE   rn_pass_high

      LDA   Itempl
      CMP   RN_OLD
      BCS   rn_pass_high

rn_pass_low
      LDA   Itempl            ; no, it keeps the number it has
      STA   RN_LNO
      LDA   Itempl+1
      STA   RN_LNO+1
      BRA   rn_pass_hdr

rn_pass_high
      LDA   RN_FLG
      AND   #RN_FRUN
      BNE   rn_pass_step      ; already inside the renumbered run

      LDA   RN_FLG            ; this is the first line of it
      ORA   #RN_FRUN
      STA   RN_FLG
      LDA   RN_NEW
      STA   RN_LNO
      LDA   RN_NEW+1
      STA   RN_LNO+1
      BRA   rn_pass_hdr

rn_pass_step
      CLC
      LDA   RN_LNO
      ADC   RN_INC
      STA   RN_LNO
      LDA   RN_LNO+1
      ADC   RN_INC+1
      STA   RN_LNO+1

; the header. the two link bytes go straight through - they are rebuilt once
; the last pass has finished - and the line number only changes on the last
; pass, because the three before it need the old ones to look references up

rn_pass_hdr
      JSR   RN_GET
      JSR   RN_PUT
      JSR   RN_GET
      JSR   RN_PUT

      LDA   RN_FLG
      AND   #RN_FPASS
      CMP   #RN_TRIM
      BNE   rn_pass_oldn

      JSR   RN_GET            ; the trim pass, so step over the old number
      JSR   RN_GET
      LDA   RN_LNO            ; and put the new one in
      JSR   RN_PUT
      LDA   RN_LNO+1
      JSR   RN_PUT
      BRA   rn_pass_clr

rn_pass_oldn
      JSR   RN_GET            ; every other pass leaves the number alone
      JSR   RN_PUT
      JSR   RN_GET
      JSR   RN_PUT

rn_pass_clr
      LDA   RN_FLG            ; every line starts outside quotes and outside
      AND   #<~(RN_FQUO|RN_FDAT)
      STA   RN_FLG            ; a DATA statement

; the crunched text. a number is only a line number where a keyword that takes
; one has just gone by, and never inside a string, a REM or a DATA item, which
; is why the quote and DATA state is tracked exactly as LAB_13A6 tracks it

rn_pass_txt
      JSR   RN_GET
      BEQ   rn_pass_eol       ; [EOL], the line is done

      BIT   RN_FLG            ; b7 inside quotes, b6 inside DATA
      BPL   rn_txt_open

      CMP   #'"'              ; inside quotes, only the closing one matters
      BNE   rn_txt_plain

      PHA
      LDA   RN_FLG
      AND   #<~RN_FQUO
      STA   RN_FLG
      PLA
      BRA   rn_txt_plain

rn_txt_open
      CMP   #'"'
      BEQ   rn_txt_quote

      CMP   #':'
      BEQ   rn_txt_colon

      BVS   rn_txt_plain      ; inside DATA, so nothing here is a keyword

      CMP   #TK_REM
      BEQ   rn_txt_rem

      CMP   #TK_DATA
      BEQ   rn_txt_data

      PHA                     ; RN_KIND wants A and gives the kind back in X
      JSR   RN_KIND
      PLA                     ; PLA does not disturb the carry
      BCS   rn_txt_ref

rn_txt_plain
      JSR   RN_PUT
      BRA   rn_pass_txt

rn_txt_quote
      PHA
      LDA   RN_FLG
      ORA   #RN_FQUO
      STA   RN_FLG
      PLA
      BRA   rn_txt_plain

rn_txt_colon
      PHA                     ; a ":" ends a DATA statement, the same way it
      LDA   RN_FLG            ; ends one for the tokenizer
      AND   #<~RN_FDAT
      STA   RN_FLG
      PLA
      BRA   rn_txt_plain

rn_txt_data
      PHA
      LDA   RN_FLG
      ORA   #RN_FDAT
      STA   RN_FLG
      PLA
      BRA   rn_txt_plain

; REM takes the rest of the line as it stands. the tokenizer does not crunch
; any of it, so there is nothing in there to fix up

rn_txt_rem
      JSR   RN_PUT
rn_txt_reml
      JSR   RN_GET
      BEQ   rn_pass_eol
      JSR   RN_PUT
      BRA   rn_txt_reml

rn_pass_eol
      JSR   RN_PUT            ; A holds the [EOL]
      JMP   RN_PASS

; a keyword that can be followed by a line number. A is the keyword, X says
; what follows it

rn_txt_ref
      PHX
      JSR   RN_PUT            ; the keyword itself is unchanged
      PLX

      CPX   #$02
      BEQ   rn_ref_list

      PHX
      JSR   RN_OPTN           ; a line number may follow
      PLX
      CPX   #$01
      BNE   rn_txt_back       ; THEN, ELSE, RUN or RESTORE, only the one

; GOTO and GOSUB, where an ON <n> GOTO list may follow. handling the commas
; here rather than special casing the ON token means ON never has to be
; recognised at all

rn_ref_lp
      JSR   RN_SPC
      CMP   #','
      BNE   rn_txt_back

      JSR   RN_GET
      JSR   RN_PUT            ; the comma
      JSR   RN_OPTN
      BRA   rn_ref_lp

; LIST n-m, where either end may be missing

rn_ref_list
      JSR   RN_OPTN
      JSR   RN_SPC
      CMP   #TK_MINUS
      BNE   rn_txt_back

      JSR   RN_GET
      JSR   RN_PUT
      JSR   RN_OPTN

rn_txt_back
      JMP   rn_pass_txt

; ---------------------------------------------------------------------------
; RN_KIND  A is a byte from the crunched text. carry set if it is a keyword
;          that can be followed by a line number, with X saying what follows:
;
;            0  just the number            THEN, ELSE, RUN, RESTORE
;            1  a number and a comma list  GOTO, GOSUB
;            2  a number, "-", a number    LIST
;
;          A comes back unchanged either way.
; ---------------------------------------------------------------------------

rn_ktab
      .byte TK_THEN
      .byte TK_ELSE
      .byte TK_RUN
      .byte TK_RESTORE
      .byte TK_GOTO
      .byte TK_GOSUB
      .byte TK_LIST
rn_kknd
      .byte $00,$00,$00,$00,$01,$01,$02

rn_ktab_len  = rn_kknd - rn_ktab

RN_KIND
      LDX   #rn_ktab_len-1
rn_kind_lp
      CMP   rn_ktab,X
      BEQ   rn_kind_hit

      DEX
      BPL   rn_kind_lp

      CLC                     ; not one of them
      RTS

rn_kind_hit
      PHA                     ; hold the keyword, X is about to be reloaded
      LDA   rn_kknd,X
      TAX
      PLA
      SEC
      RTS

; ---------------------------------------------------------------------------
; RN_OPTN  pass any spaces through, and if a line number follows do it.
; RN_SPC   pass any spaces at RN_SRC through, and return with the first byte
;          that is not a space in A, still unread.
;
; The tokenizer keeps the spaces it was given, so GOTO 100 has one sitting
; between the keyword and the digits.
; ---------------------------------------------------------------------------

RN_OPTN
      JSR   RN_SPC
      CMP   #'0'
      BCC   rn_optn_end

      CMP   #'9'+1
      BCS   rn_optn_end

      JMP   RN_NUM

rn_optn_end
      RTS

RN_SPC
      LDA   (RN_SRC)
      CMP   #' '
      BNE   rn_spc_end

      JSR   RN_GET
      JSR   RN_PUT
      BRA   RN_SPC

rn_spc_end
      RTS

; ---------------------------------------------------------------------------
; RN_NUM   a line number reference starts at RN_SRC. what happens to it is up
;          to the pass:
;
;   measure  count what padding it out to five digits would cost
;   widen    pad it out to five digits
;   map      look the line up and put the new number in the same five digits
;   trim     take the padding back off
;
; Anything that is not five digits by the time the mapping pass sees it is not
; a line number - it is longer than one can be - and is left alone by both of
; the passes that would otherwise change it.
; ---------------------------------------------------------------------------

RN_NUM
      LDY   #$00              ; count the digits without taking them yet
rn_num_cnt
      LDA   (RN_SRC),Y
      CMP   #'0'
      BCC   rn_num_got

      CMP   #'9'+1
      BCS   rn_num_got

      INY
      BNE   rn_num_cnt        ; a digit run cannot reach 256, the input buffer
                              ; is nothing like that long

rn_num_got
      LDA   RN_FLG
      AND   #RN_FPASS
      BEQ   rn_num_meas       ; the measuring pass

      CMP   #RN_WIDE
      BEQ   rn_num_wide

      CPY   #RN_WIDTH         ; the two passes below only ever look at a
      BNE   rn_num_raw        ; reference the widening pass has been over

      CMP   #RN_MAPP
      BEQ   rn_num_map

; the trimming pass. drop leading zeros, but never the last digit

rn_num_trim
      LDA   (RN_SRC)
      CMP   #'0'
      BNE   rn_num_raw

      CPY   #$01
      BEQ   rn_num_raw        ; one left, and a number needs a digit

      JSR   RN_GET            ; take the zero and do not pass it on
      DEY
      BRA   rn_num_trim

; the measuring pass. a reference of one to five digits becomes five, and
; anything longer is not a line number and is left as it is

rn_num_meas
      CPY   #RN_WIDTH
      BCS   rn_num_raw

      TYA
      EOR   #$FF              ; RN_GRW += RN_WIDTH - Y
      SEC
      ADC   #RN_WIDTH
      CLC
      ADC   RN_GRW
      STA   RN_GRW
      BCC   rn_num_raw

      INC   RN_GRW+1
      BRA   rn_num_raw

; the widening pass. put the missing leading zeros in ahead of the digits

rn_num_wide
      CPY   #RN_WIDTH
      BCS   rn_num_raw

      TYA
      PHA                     ; how many digits there are
      EOR   #$FF
      SEC
      ADC   #RN_WIDTH
      TAX                     ; how many zeros go in front of them
rn_num_wlp
      LDA   #'0'
      JSR   RN_PUT
      DEX
      BNE   rn_num_wlp

      PLA
      TAY
      BRA   rn_num_raw

; the mapping pass. five digits in, and five digits back out

rn_num_map
      JSR   RN_VAL            ; read the five digits, carry clear if they do
      BCC   rn_num_raw        ; not make a line number at all

      PHY                     ; RN_MAP walks the program with Y, and Y is
      JSR   RN_MAP            ; still the digit count
      PLY                     ; PLY does not disturb the carry
      BCS   rn_num_new

      JSR   RN_UNDEF          ; names no line, say so and leave it alone
      BRA   rn_num_raw

rn_num_new
      TYA                     ; step the source past the old five
      CLC
      ADC   RN_SRC
      STA   RN_SRC
      BCC   RN_PUTN

      INC   RN_SRC+1
      BRA   RN_PUTN           ; and put the new five out

; pass the digits through exactly as they stand. Y is how many are left

rn_num_raw
      CPY   #$00
      BEQ   rn_num_ret

rn_num_rawl
      JSR   RN_GET
      JSR   RN_PUT
      DEY
      BNE   rn_num_rawl

rn_num_ret
      RTS

; ---------------------------------------------------------------------------
; RN_VAL   read the Y digits at RN_SRC into Itempl/Itempl+1 without taking
;          them. carry clear if they come to more than a line number can hold.
;          Y comes back unchanged.
; ---------------------------------------------------------------------------

RN_VAL
      STZ   Itempl
      STZ   Itempl+1
      PHY
      LDY   #$00
rn_val_lp
      LDA   Itempl+1          ; would another digit take it past 63999? this
      CMP   #$19              ; is LAB_GFPN's own test
      BCS   rn_val_big

      LDA   (RN_SRC),Y
      SEC
      SBC   #'0'
      PHA                     ; the digit, for after the multiply

      ASL   Itempl            ; *2
      ROL   Itempl+1
      LDA   Itempl+1
      PHA                     ; keep *2, high byte first so that the low one
      LDA   Itempl            ; comes back off first
      PHA
      ASL   Itempl            ; *4
      ROL   Itempl+1
      ASL   Itempl            ; *8
      ROL   Itempl+1
      PLA                     ; *2 low byte
      CLC
      ADC   Itempl
      STA   Itempl
      PLA                     ; *2 high byte
      ADC   Itempl+1
      STA   Itempl+1          ; *8 + *2, so *10

      PLA                     ; and the digit
      CLC
      ADC   Itempl
      STA   Itempl
      BCC   rn_val_nc

      INC   Itempl+1
rn_val_nc
      INY
      CPY   #RN_WIDTH
      BNE   rn_val_lp

      PLY
      SEC                     ; it is a line number
      RTS

rn_val_big
      PLY
      CLC                     ; it is not
      RTS

; ---------------------------------------------------------------------------
; RN_PUTN  hand Itempl/Itempl+1 to the output as exactly five digits, leading
;          zeros and all. Destroys Itempl/Itempl+1.
; ---------------------------------------------------------------------------

rn_p10
      .word 10000
      .word 1000
      .word 100
      .word 10
      .word 1

RN_PUTN
      LDX   #$00              ; index into the powers of ten
rn_putn_pow
      LDA   #'0'
      PHA                     ; the digit for this power, kept on the stack
                              ; because there is no register left to hold it
rn_putn_sub
      SEC
      LDA   Itempl
      SBC   rn_p10,X
      STA   Itempl
      LDA   Itempl+1
      SBC   rn_p10+1,X
      STA   Itempl+1
      BCC   rn_putn_back      ; went under, this power is done

      PLA
      INC   A
      PHA
      BRA   rn_putn_sub

rn_putn_back
      CLC                     ; put the power back on
      LDA   Itempl
      ADC   rn_p10,X
      STA   Itempl
      LDA   Itempl+1
      ADC   rn_p10+1,X
      STA   Itempl+1

      PLA
      JSR   RN_PUT
      INX
      INX
      CPX   #$0A
      BNE   rn_putn_pow

      RTS

; ---------------------------------------------------------------------------
; RN_UNDEF  Itempl/Itempl+1 names no line in the program. Say so, but only on
;           the mapping pass, which is the only one that looks anything up.
; ---------------------------------------------------------------------------

RN_UNDEF
      PHY
      LDA   #<rn_msg_und
      LDY   #>rn_msg_und
      JSR   LAB_18C3
      LDX   Itempl
      LDA   Itempl+1
      JSR   LAB_295E          ; the number that names nothing
      LDA   #<rn_msg_inl
      LDY   #>rn_msg_inl
      JSR   LAB_18C3
      LDX   RN_LNO
      LDA   RN_LNO+1
      JSR   LAB_295E          ; and the line it sits in, by its new number
      PLY
      RTS

rn_msg_und
      .byte $0D,$0A,"Undefined ",$00
rn_msg_inl
      .byte " in line ",$00

; ---------------------------------------------------------------------------
; RN_MAP   Itempl/Itempl+1 holds an old line number. Return the new one in the
;          same place with carry set, or carry clear and it untouched if no
;          line in the program carries that number. X is left alone, Y is not.
;
; Only the mapping pass calls this, and that pass does not move anything, so
; the whole program is sitting there on its old numbers to be walked.
;
; ---------------------------------------------------------------------------

RN_MAP
      LDA   Itempl+1
      CMP   RN_OLD+1
      BCC   rn_map_keep       ; below the first line being renumbered, so it
      BNE   rn_map_scan       ; keeps the number it has

      LDA   Itempl
      CMP   RN_OLD
      BCC   rn_map_keep

rn_map_scan
      LDA   Smeml
      STA   RN_MPT
      LDA   Smeml+1
      STA   RN_MPT+1
      LDA   RN_NEW
      STA   RN_CUR
      LDA   RN_NEW+1
      STA   RN_CUR+1

rn_map_lp
      LDY   #$01
      LDA   (RN_MPT),Y
      BEQ   rn_map_no         ; end of the program, it was never there

      LDY   #$03
      LDA   (RN_MPT),Y        ; is this line one of the renumbered ones?
      CMP   RN_OLD+1
      BCC   rn_map_step
      BNE   rn_map_here

      DEY
      LDA   (RN_MPT),Y
      CMP   RN_OLD
      BCC   rn_map_step

rn_map_here
      LDY   #$03              ; it is, so compare it with the wanted number
      LDA   (RN_MPT),Y
      CMP   Itempl+1
      BCC   rn_map_next
      BNE   rn_map_no         ; gone past it, so it is not there

      DEY
      LDA   (RN_MPT),Y
      CMP   Itempl
      BCC   rn_map_next
      BNE   rn_map_no

      LDA   RN_CUR            ; found it
      STA   Itempl
      LDA   RN_CUR+1
      STA   Itempl+1
      SEC
      RTS

rn_map_next
      CLC                     ; not this one, so the next renumbered line
      LDA   RN_CUR            ; takes the next number
      ADC   RN_INC
      STA   RN_CUR
      LDA   RN_CUR+1
      ADC   RN_INC+1
      STA   RN_CUR+1

rn_map_step
      JSR   RN_NXTM
      BRA   rn_map_lp

rn_map_no
      CLC
      RTS

rn_map_keep
      SEC
      RTS

; ---------------------------------------------------------------------------
; RN_NXTM  step RN_MPT on to the next line header.
;
; Both callers walk a program whose chain is good - RN_CHK before anything has
; moved, RN_MAP after RN_CHAIN has put it back - so this can follow the next
; line pointers rather than hunting for each line's [EOL]. On a long program
; that is most of what a renumber costs, RN_MAP walks the chain once for every
; reference in the program.
; ---------------------------------------------------------------------------

RN_NXTM
      LDY   #$00
      LDA   (RN_MPT),Y
      TAX
      INY
      LDA   (RN_MPT),Y
      STX   RN_MPT
      STA   RN_MPT+1
      RTS

; ---------------------------------------------------------------------------
; RN_GET   read the byte at RN_SRC and step the pointer on.
; RN_PUT   hand the byte in A to the output, which is a store at RN_DST on
;          every pass but the measuring one, which has nowhere to put it.
;
; Both leave X and Y alone, which everything above relies on.
; ---------------------------------------------------------------------------

RN_GET
      LDA   (RN_SRC)
      INC   RN_SRC
      BNE   rn_get_end

      INC   RN_SRC+1
rn_get_end
      CMP   #$00              ; the pointer step left the flags on itself
      RTS

RN_PUT
      PHA
      LDA   RN_FLG
      AND   #RN_FPASS
      BEQ   rn_put_end        ; measuring, so there is nowhere to put it

      PLA
      STA   (RN_DST)
      INC   RN_DST
      BNE   rn_put_ret

      INC   RN_DST+1
rn_put_ret
      RTS

rn_put_end
      PLA
      RTS

.if LCD_BUILT

; ---------------------------------------------------------------------------
; HD44780 LCD in 4 bit mode on VIA port B
;
; Ported from imdlabs_lcd.s, the same command set this board's Microsoft BASIC
; ROM carries, which in turn builds on Ben Eater's lcd.s. The low level driver
; below - lcd_wait, LCDINIT, lcd_instruction and lcd_print_char - is his code
; unchanged. What changed in the port is the parameter fetching: MS-BASIC's
; GETBYT, FRMNUM, AYINT, FRMEVL and FREFAC became the EhBASIC equivalents
; listed at the top of this file.
; ---------------------------------------------------------------------------

PORTB = $6000
DDRB  = $6002

E  = %01000000
RW = %00100000
RS = %00010000

; LCD instruction constants

LCD_CLEAR_SCREEN  = %00000001
LCD_CURSOR_HOME   = %00000010

LCD_SET_CGRAM_ADR = %01000000 ; output writes to custom character bitmaps
LCD_SET_DDRAM_ADR = %10000000 ; output writes characters to screen

; LCD_SHIFT is used in conjunction with CURSOR_LEFT, CURSOR_RIGHT,
; DISPLAY_LEFT and DISPLAY_RIGHT. OR LCD_SHIFT with the desired action
; to create the full instruction

LCD_SHIFT         = %00010000
LCD_CURSOR_LEFT   = %00000000
LCD_CURSOR_RIGHT  = %00000100
LCD_DISPLAY_LEFT  = %00001000
LCD_DISPLAY_RIGHT = %00001100

; LCD_DISPLAY_CONTROL is used in conjunction with DISPLAY_ENABLE, CURSOR_ENABLE
; and CURSOR_BLINK. OR LCD_DISPLAY_CONTROL with the desired action to create
; the full instruction

LCD_DISPLAY_CONTROL = %00001000
LCD_DISPLAY_ENABLE  = %00000100
LCD_CURSOR_ENABLE   = %00000010
LCD_CURSOR_BLINK    = %00000001

; the HD44780 wants more than 15ms after Vcc comes up before it will accept its
; first instruction. RES_vec reaches LCDINIT microseconds after reset, far
; sooner than that, so the wait has to be made rather than assumed - without it
; a cold power on can leave the display blank or garbled while a warm reset,
; which has had the time, looks fine.
;
; the inner loop is 5 cycles a pass (DEY 2, BNE taken 3) and runs 256 times, so
; one outer pass is about 1286 cycles. LCD_WARMUP outer passes gives
;
;   1 MHz   $30 passes = 62ms      the stock BE6502
;   2 MHz              = 31ms
;   4 MHz              = 15ms
;
; sized for a 1 MHz board with enough in hand to still clear 15ms on one
; clocked up to 4 MHz. it costs nothing anywhere else, it runs once at reset

LCD_WARMUP = $30

; wait for the LCD's busy flag to clear, port B is left as an output

lcd_wait
      PHA
      LDA   #%11110000        ; LCD data is input
      STA   DDRB
lcdbusy
      LDA   #RW
      STA   PORTB
      LDA   #(RW | E)
      STA   PORTB
      LDA   PORTB             ; read high nibble
      PHA                     ; and put on stack since it has the busy flag
      LDA   #RW
      STA   PORTB
      LDA   #(RW | E)
      STA   PORTB
      LDA   PORTB             ; read low nibble
      PLA                     ; get high nibble off stack
      AND   #%00001000
      BNE   lcdbusy

      LDA   #RW
      STA   PORTB
      LDA   #%11111111        ; LCD data is output
      STA   DDRB
      PLA
      RTS

; bring the display up in 4 bit mode, 2 lines, 5x8 font, cursor on, no blink.
; called from RES_vec in min_mon.s, not reachable from BASIC

LCDINIT
      LDX   #LCD_WARMUP       ; wait out the display's power on time, see above
lcd_warmup_outer
      LDY   #$00              ; 256 passes of the inner loop
lcd_warmup_inner
      DEY
      BNE   lcd_warmup_inner
      DEX
      BNE   lcd_warmup_outer

      LDA   #$FF              ; set all pins on port B to output
      STA   DDRB

      LDA   #%00000011        ; set 8-bit mode
      STA   PORTB
      ORA   #E
      STA   PORTB
      AND   #%00001111
      STA   PORTB

      LDA   #%00000011        ; set 8-bit mode
      STA   PORTB
      ORA   #E
      STA   PORTB
      AND   #%00001111
      STA   PORTB

      LDA   #%00000011        ; set 8-bit mode
      STA   PORTB
      ORA   #E
      STA   PORTB
      AND   #%00001111
      STA   PORTB

; now we really are in 8 bit mode, so the command to get to 4 bit mode will
; be understood

      LDA   #%00000010        ; set 4-bit mode
      STA   PORTB
      ORA   #E
      STA   PORTB
      AND   #%00001111
      STA   PORTB

      LDA   #%00101000        ; 4-bit mode, 2 line display, 5x8 font
      JSR   lcd_instruction
      LDA   #%00001110        ; display on, cursor on, blink off
      JSR   lcd_instruction
      LDA   #%00000110        ; increment and shift cursor, don't shift display
      JSR   lcd_instruction
      LDA   #%00000001        ; clear display
      JSR   lcd_instruction
      RTS

; LCDCMD n    send raw instruction byte n to the LCD.
;
; falls through into lcd_instruction, which is also the internal entry point
; every command below uses. RS is left clear, so the byte is an instruction
; rather than character data

LCDCMD
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A
lcd_instruction
      JSR   lcd_wait
      PHA
      LSR
      LSR
      LSR
      LSR                     ; send high 4 bits
      STA   PORTB
      ORA   #E                ; set E bit to send instruction
      STA   PORTB
      EOR   #E                ; clear E bit
      STA   PORTB
      PLA
      AND   #%00001111        ; send low 4 bits
      STA   PORTB
      ORA   #E                ; set E bit to send instruction
      STA   PORTB
      EOR   #E                ; clear E bit
      STA   PORTB
      RTS

; send one byte of character data, RS set

lcd_print_char
      JSR   lcd_wait
      PHA
      LSR
      LSR
      LSR
      LSR                     ; send high 4 bits
      ORA   #RS               ; set RS
      STA   PORTB
      ORA   #E                ; set E bit to send instruction
      STA   PORTB
      EOR   #E                ; clear E bit
      STA   PORTB
      PLA
      AND   #%00001111        ; send low 4 bits
      ORA   #RS               ; set RS
      STA   PORTB
      ORA   #E                ; set E bit to send instruction
      STA   PORTB
      EOR   #E                ; clear E bit
      STA   PORTB
      RTS

; LCDPRINT expr[;|, expr ..]
;
; unlike the MS-BASIC version this takes a full PRINT style list, so
; LCDPRINT "N=";N works. ";" and "," are both plain separators, there are no
; tab stops to move to on a 16 or 20 column display.
;
; the structure is EhBASIC's own PRINT (LAB_PRINT in basic.s) with lcd_puts in
; place of the serial output. entered with A and the flags already holding the
; byte after the token, the dispatch does that with its JMP LAB_IGBY.
;
; LCDCGCHRS is the same routine. Writing to the display and writing to the
; character generator differ only in where the LCD's address counter is
; pointing, which LCDCGRAM sets, so the same code serves both.

LCDPRINT
LCDCGCHRS
      BEQ   lcdp_done         ; nothing following, so nothing to print
lcdp_item
      CMP   #';'              ; compare with ";"
      BEQ   lcdp_sep          ; if ";" step over it

      CMP   #','              ; compare with ","
      BEQ   lcdp_sep          ; if "," step over it

      JSR   LAB_EVEX          ; evaluate expression
      BIT   Dtypef            ; test data type flag, $FF=string, $00=numeric
      BMI   lcdp_send         ; branch if string

      JSR   LAB_296E          ; convert FAC1 to string, AY = pointer
      JSR   LAB_20AE          ; make a descriptor from the " terminated string
lcdp_send
      JSR   lcd_puts          ; pop the descriptor and send it
      JSR   LAB_GBYT          ; scan memory, LAB_EVEX has already stepped past
      BNE   lcdp_item         ; if not end of statement go do the next item

      RTS

lcdp_sep
      JSR   LAB_IGBY          ; increment and scan past the separator
      BNE   lcdp_item         ; if not end of statement go do the next item

lcdp_done
      RTS

; pop the string on the top of the descriptor stack and send it to the LCD.
; this is LAB_18C6 from basic.s with lcd_print_char for LAB_PRNA, including
; its length test ahead of the loop. the MS-BASIC original tests after, so a
; null string sends 256 characters there and none here

lcd_puts
      JSR   LAB_22B6          ; pop string off the descriptor stack, A = length,
                              ; pointer in ut1_pl/ut1_ph
      LDY   #$00              ; reset index
      TAX                     ; copy length to X
      BEQ   lcd_puts_end      ; exit if null string

lcd_puts_lp
      LDA   (ut1_pl),Y        ; get next byte
      JSR   lcd_print_char    ; send it
      INY                     ; increment index
      DEX                     ; decrement count
      BNE   lcd_puts_lp       ; loop if not done yet

lcd_puts_end
      RTS

; LCDCLS      clear the display, which also sends the cursor home

LCDCLS
      LDA   #LCD_CLEAR_SCREEN
      JMP   lcd_instruction   ; go send it and return

; LCDHOME     send the cursor to the first character of the first line

LCDHOME
      LDA   #LCD_CURSOR_HOME
      JMP   lcd_instruction   ; go send it and return

; LCDCURPOS n / LCDDDRAM n
;
; set the DDRAM address, a zero based offset into display memory, which is
; where the next character written will land. That moves the cursor with it.
; On a 2 line module the second line starts at $40, not at the end of the first

LCDCURPOS
LCDDDRAM
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A
      ORA   #LCD_SET_DDRAM_ADR
                              ; the instruction is the DDRAM one ORd with the offset
      JMP   lcd_instruction   ; go send it and return

; LCDCGRAM n
;
; set CGRAM mode and address. Data sent to the LCD in this mode writes into the
; custom character set instead of the screen. There are 8 user definable
; characters of 8 bytes each, 8 rows of 5 pixels, where the first byte of CGRAM
; is the top row of character 0 and the eighth is its bottom row. Only the low
; 5 bits of each byte are used, a set bit being a lit pixel.
;
; Call LCDCGRAM 0 for the start of the character data, or the character you
; want multiplied by 8. It is a byte offset, so it can also address any single
; row of any character

LCDCGRAM
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A
      ORA   #LCD_SET_CGRAM_ADR
                              ; the instruction is the CGRAM one ORd with the offset
      JMP   lcd_instruction   ; go send it and return

; LCDCGBYTE n
;
; write one byte of character bitmap data. Use this to send numeric values to
; the CGRAM area, LCDCGCHRS when what you have is a string of character codes

LCDCGBYTE
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A
      JMP   lcd_print_char    ; send it as data, RS set, and return

; LCDCURENABLE n
;
; 0 turns the cursor off, anything else turns it on. This always enables the
; display, and it rewrites the whole display control byte, so it also clears
; blink. LCDCMD is the way to set the odd combinations, cursor on with the
; display off and so on

LCDCURENABLE
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A, sets the flags on it
      BEQ   lcd_cursor_off    ; if zero go turn the cursor off

      LDA   #(LCD_DISPLAY_CONTROL | LCD_DISPLAY_ENABLE | LCD_CURSOR_ENABLE)
      JMP   lcd_instruction   ; go send it and return

lcd_cursor_off
      LDA   #(LCD_DISPLAY_CONTROL | LCD_DISPLAY_ENABLE)
      JMP   lcd_instruction   ; go send it and return

; LCDCURBLINK n
;
; 0 stops the cursor blinking, anything else starts it. Same caveats as
; LCDCURENABLE, it always enables the display and rewrites the whole control
; byte. Turning blink off here leaves a solid cursor on, which is what the
; MS-BASIC version does

LCDCURBLINK
      JSR   LAB_GTBY          ; get byte parameter
      TXA                     ; copy it to A, sets the flags on it
      BEQ   lcd_blink_off     ; if zero go stop the blink

      LDA   #(LCD_DISPLAY_CONTROL | LCD_DISPLAY_ENABLE | LCD_CURSOR_BLINK)
      JMP   lcd_instruction   ; go send it and return

lcd_blink_off
      LDA   #(LCD_DISPLAY_CONTROL | LCD_DISPLAY_ENABLE | LCD_CURSOR_ENABLE)
      JMP   lcd_instruction   ; go send it and return

; LCDMOVECUR n
;
; move the cursor left (n negative) or right (n positive) n characters. The
; cursor wraps at the display extents, so counts larger than the display go
; round.
;
; LAB_EVIR leaves the value as a signed 16 bit integer in FAC1_2 (high) and
; FAC1_3 (low), the same layout MS-BASIC's AYINT uses. Note the order of the
; two loads: the sign test has to be on the high byte, the count is the low
; one, and the imdlabs_lcd.s original loaded them the other way round so that
; the BPL tested the wrong byte and read 128..255 as negative

LCDMOVECUR
      JSR   LAB_EVNM          ; evaluate expression and check is numeric
      JSR   LAB_EVIR          ; convert FAC1 float to fixed, no sign check
      LDX   FAC1_3            ; low byte is the move count
      LDA   FAC1_2            ; high byte, $00 = +ve, $FF = -ve
      BMI   lcd_movecur_neg   ; branch if -ve, go move left

      TXA                     ; set the flags on the count
      BEQ   lcd_move_done     ; move is 0, so nothing to do

lcd_movecur_right
      LDA   #(LCD_SHIFT | LCD_CURSOR_RIGHT)
      JSR   lcd_instruction
      DEX                     ; decrement count
      BNE   lcd_movecur_right ; loop if not done yet

lcd_move_done
      RTS

lcd_movecur_neg
      TXA                     ; twos complement the low byte for the magnitude
      EOR   #$FF
      TAX
      INX
      BEQ   lcd_move_done     ; move is 0, so nothing to do

lcd_movecur_left
      LDA   #(LCD_SHIFT | LCD_CURSOR_LEFT)
      JSR   lcd_instruction
      DEX                     ; decrement count
      BNE   lcd_movecur_left  ; loop if not done yet

      RTS

; LCDSCROLL n
;
; scroll the display left (n negative) or right (n positive) n characters.
; Characters wrap at the display extents. Same signed argument handling as
; LCDMOVECUR above

LCDSCROLL
      JSR   LAB_EVNM          ; evaluate expression and check is numeric
      JSR   LAB_EVIR          ; convert FAC1 float to fixed, no sign check
      LDX   FAC1_3            ; low byte is the scroll count
      LDA   FAC1_2            ; high byte, $00 = +ve, $FF = -ve
      BMI   lcd_scroll_neg    ; branch if -ve, go scroll left

      TXA                     ; set the flags on the count
      BEQ   lcd_scroll_done   ; scroll is 0, so nothing to do

lcd_scroll_right
      LDA   #(LCD_SHIFT | LCD_DISPLAY_RIGHT)
      JSR   lcd_instruction
      DEX                     ; decrement count
      BNE   lcd_scroll_right  ; loop if not done yet

lcd_scroll_done
      RTS

lcd_scroll_neg
      TXA                     ; twos complement the low byte for the magnitude
      EOR   #$FF
      TAX
      INX
      BEQ   lcd_scroll_done   ; scroll is 0, so nothing to do

lcd_scroll_left
      LDA   #(LCD_SHIFT | LCD_DISPLAY_LEFT)
      JSR   lcd_instruction
      DEX                     ; decrement count
      BNE   lcd_scroll_left   ; loop if not done yet

      RTS

.endif
