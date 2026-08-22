.setcpu "65C02"

; WozMon, integrated with EhBASIC. it is entered by EhBASIC's MONITOR command
; (see custom_commands.s) and left with 8000R, which returns to the sign on
; and the [C]old/[W]arm prompt. 8006R goes straight back to a warm start with
; the BASIC program still in memory.
;
; the serial primitives come from min_mon.s rather than being duplicated here,
; so this copy is specific to this project.

.export WOZMON
.import CHRIN, CHROUT

.segment "WOZMON"

; zero page. $13-$5A is the hole EhBASIC leaves unused, see basic.s, so none
; of this disturbs a BASIC program waiting to be warm started

XAML            = $24                   ; Last "opened" location Low
XAMH            = $25                   ; Last "opened" location High
STL             = $26                   ; Store address Low
STH             = $27                   ; Store address High
L               = $28                   ; Hex value parsing Low
H               = $29                   ; Hex value parsing High
YSAV            = $2A                   ; Used to see if hex value is given
MODE            = $2B                   ; $00=XAM, $7F=STOR, $AE=BLOCK XAM

; the line buffer cannot live at $0200 as it does on an Apple 1, that is
; EhBASIC's page 2: ccflag and the I/O vectors ($0200-$020C), the IRQ/NMI code
; copied there at reset ($020D-$0220) and Ibuffs..Ibuffe ($0221-$0268).
; page 2's tail is free, and $0280 gives exactly the $80 bytes Y = $00-$7F
; needs without running into the serial ring buffer at $0300.

IN              = $0280                 ; Input buffer

; entry from EhBASIC's MONITOR command. the ACIA and the receive ring buffer
; are already set up by min_mon.s at reset, and re-programming the ACIA here
; would drop any byte in the middle of being received, so neither is touched.

WOZMON:
                CLD                     ; Clear decimal arithmetic mode.
                CLI                     ; CHRIN needs receive interrupts live.
                BRA     ESCAPE          ; Sign on with "\" and a fresh line,
                                        ; same as WozMon does out of reset.

NOTCR:
                CMP     #$08            ; Backspace key?
                BEQ     BACKSPACE       ; Yes.
                CMP     #$1B            ; ESC?
                BEQ     ESCAPE          ; Yes.
                INY                     ; Advance text index.
                BPL     NEXTCHAR        ; Auto ESC if line longer than 127.

ESCAPE:
                LDA     #$5C            ; "\".
                JSR     ECHO            ; Output it.

GETLINE:
                LDA     #$0D            ; Send CR
                JSR     ECHO
                LDA     #$0A            ; Send LF
                JSR     ECHO

                LDY     #$00            ; Initialize text index.
                BRA     NEXTCHAR

; NEXTCHAR has already echoed the BS itself, so the cursor has moved back over
; the character being deleted; overwrite it with a space and back up again so
; the cursor ends up where the deleted character used to be.
BACKSPACE:      DEY                     ; Back up text index.
                BMI     GETLINE         ; Beyond start of line, reinitialize.
                LDA     #$20            ; Space, erasing the character.
                JSR     ECHO            ; Output it.
                LDA     #$08            ; Backspace, back over the space.
                JSR     ECHO            ; Output it.

NEXTCHAR:
                JSR     CHRIN
                BCC     NEXTCHAR
                STA     IN,Y            ; Add to text buffer.
                JSR     ECHO            ; Echo it. CHRIN does not, EhBASIC
                                        ; echoes for itself to track its
                                        ; terminal column, so we do our own.
                CMP     #$0D            ; CR?
                BNE     NOTCR           ; No.

                LDY     #$FF            ; Reset text index.
                LDA     #$00            ; For XAM mode.
                TAX                     ; X=0.
SETBLOCK:
                ASL
SETSTOR:
                ASL                     ; Leaves $7B if setting STOR mode.
SETMODE:
                STA     MODE            ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.
BLSKIP:
                INY                     ; Advance text index.
NEXTITEM:
                LDA     IN,Y            ; Get character.
                CMP     #$0D            ; CR?
                BEQ     GETLINE         ; Yes, done this line.
                CMP     #$2E            ; "."?
                BCC     BLSKIP          ; Skip delimiter.
                BEQ     SETBLOCK        ; Set BLOCK XAM mode.
                CMP     #$3A            ; ":"?
                BEQ     SETSTOR         ; Yes, set STOR mode.
                CMP     #$52            ; "R"?
                BEQ     RUNPROG         ; Yes, run user program.
                STX     L               ; $00 -> L.
                STX     H               ;    and H.
                STY     YSAV            ; Save Y for comparison

NEXTHEX:
                LDA     IN,Y            ; Get character for hex test.
                EOR     #$30            ; Map digits to $0-9.
                CMP     #$0A            ; Digit?
                BCC     DIG             ; Yes.
                ADC     #$88            ; Map letter "A"-"F" to $FA-FF.
                CMP     #$FA            ; Hex letter?
                BCC     NOTHEX          ; No, character not hex.
DIG:
                ASL
                ASL                     ; Hex digit to MSD of A.
                ASL
                ASL

                LDX     #$04            ; Shift count.
HEXSHIFT:
                ASL                     ; Hex digit left, MSB to carry.
                ROL     L               ; Rotate into LSD.
                ROL     H               ; Rotate into MSD's.
                DEX                     ; Done 4 shifts?
                BNE     HEXSHIFT        ; No, loop.
                INY                     ; Advance text index.
                BNE     NEXTHEX         ; Always taken. Check next character for hex.

NOTHEX:
                CPY     YSAV            ; Check if L, H empty (no hex digits).
                BEQ     ESCAPE          ; Yes, generate ESC sequence.

                BIT     MODE            ; Test MODE byte.
                BVC     NOTSTOR         ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

                LDA     L               ; LSD's of hex data.
                STA     (STL,X)         ; Store current 'store index'.
                INC     STL             ; Increment store index.
                BNE     NEXTITEM        ; Get next item (no carry).
                INC     STH             ; Add carry to 'store index' high order.
TONEXTITEM:     JMP     NEXTITEM        ; Get next command item.

RUNPROG:
                JMP     (XAML)          ; Run at current XAM index.

NOTSTOR:
                BMI     XAMNEXT         ; B7 = 0 for XAM, 1 for BLOCK XAM.

                LDX     #$02            ; Byte count.
SETADR:         LDA     L-1,X           ; Copy hex data to
                STA     STL-1,X         ;  'store index'.
                STA     XAML-1,X        ; And to 'XAM index'.
                DEX                     ; Next of 2 bytes.
                BNE     SETADR          ; Loop unless X = 0.

NXTPRNT:
                BNE     PRDATA          ; NE means no address to print.
                LDA     #$0D            ; CR.
                JSR     ECHO            ; Output it.
                LDA     #$0A            ; LF.
                JSR     ECHO            ; Output it.
                LDA     XAMH            ; 'Examine index' high-order byte.
                JSR     PRBYTE          ; Output it in hex format.
                LDA     XAML            ; Low-order 'examine index' byte.
                JSR     PRBYTE          ; Output it in hex format.
                LDA     #$3A            ; ":".
                JSR     ECHO            ; Output it.

PRDATA:
                LDA     #$20            ; Blank.
                JSR     ECHO            ; Output it.
                LDA     (XAML,X)        ; Get data byte at 'examine index'.
                JSR     PRBYTE          ; Output it in hex format.
XAMNEXT:        STX     MODE            ; 0 -> MODE (XAM mode).
                LDA     XAML
                CMP     L               ; Compare 'examine index' to hex data.
                LDA     XAMH
                SBC     H
                BCS     TONEXTITEM      ; Not less, so no more data to output.

                INC     XAML
                BNE     MOD8CHK         ; Increment 'examine index'.
                INC     XAMH

MOD8CHK:
                LDA     XAML            ; Check low-order 'examine index' byte
                AND     #$07            ; For MOD 8 = 0
                BPL     NXTPRNT         ; Always taken.

PRBYTE:
                PHA                     ; Save A for LSD.
                LSR
                LSR
                LSR                     ; MSD to LSD position.
                LSR
                JSR     PRHEX           ; Output hex digit.
                PLA                     ; Restore A.

PRHEX:
                AND     #$0F            ; Mask LSD for hex print.
                ORA     #$30            ; Add "0".
                CMP     #$3A            ; Digit?
                BCC     ECHO            ; Yes, output it.
                ADC     #$06            ; Add offset for letter.

; min_mon.s owns the 65C51 transmit bug workaround, so send through CHROUT
; rather than keeping a second copy of the delay loop here. this stays a local
; label because PRHEX reaches it with a BCC and CHROUT is far out of range.

ECHO:           JMP     CHROUT          ; Output character, preserves A.


