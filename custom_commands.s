; Command bodies for the keywords this project adds to EhBASIC.
;
; The token tables themselves have to live in basic.s (TK_* equates, LAB_CTBL,
; TAB_ASCx and LAB_KEYT), so the edits there are kept to table entries and the
; code that runs sits here.

      .export LAB_MONITOR
      .import WOZMON, CHROUT

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
