; Command bodies for the keywords this project adds to EhBASIC.
;
; The token tables themselves have to live in basic.s (TK_* equates, LAB_CTBL,
; TAB_ASCx and LAB_KEYT), so the edits there are kept to table entries and the
; code that runs sits here.

      .export LAB_MONITOR
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
; has no zero page mode and assembles as absolute either way

      .importzp LAB_IGBY, LAB_GBYT
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
