; minimal monitor for EhBASIC and 6502 simulator V1.05
; tabs converted to space, tabwidth=6

; To run EhBASIC on the simulator load and assemble [F7] this file, start the simulator
; running [F6] then start the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

; The MONITOR command body lives in custom_commands.s. importing it here,
; ahead of the include, keeps the edits to basic.s down to table entries

      .import LAB_MONITOR

; CHRIN and CHROUT are the serial primitives, wozmon.s uses them rather than
; carrying its own copy of the 65C51 transmit bug workaround

      .export CHRIN, CHROUT

      .include "basic.s"

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

; reset vector points here

RES_vec
      CLD                     ; clear decimal mode
      LDX   #$FF              ; empty stack
      TXS                     ; set the stack
      JSR   ACIAsetup         ; init ring buffer and ACIA (receiver IRQ enabled)

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
      
