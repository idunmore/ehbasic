; Included by assembler.s, which has already computed the build flags,
; imported the EhBASIC internals and selected the CODE segment.
;
;   DASM start[,count]    disassemble count instructions from start,
;                         count defaults to 20
;
; The same two tables the assembler searches are indexed directly here, so
; opcode -> mnemonic + mode needs no reverse index at all. Output goes through
; LAB_PRNA rather than CHROUT so the terminal column stays right and a PRINT
; afterwards still tabs and wraps where it should.

DASM_DEFAULT = 20             ; instructions per DASM when no count is given

; ---------------------------------------------------------------------------
; Operand formatting, one six byte row per addressing mode
;
;   kind   what to print between the prefix and the suffix
;   pre    up to two literal characters before it
;   post   up to three after it
;
; $00 in any character slot means "nothing there"
; ---------------------------------------------------------------------------

DK_NONE      = 0              ; no value at all
DK_BYTE      = 1              ; one byte, "$nn"
DK_WORD      = 2              ; two bytes, "$nnnn"
DK_REL       = 3              ; branch, target = PC + 2 + signed offset
DK_ZPREL     = 4              ; BBR/BBS, "$nn,$nnnn", offset from PC + 3

MODEFMT
      ;      kind      pre         post
      .byte DK_NONE,  0,   0,    0,   0,   0    ; MD_IMP
      .byte DK_NONE, 'A',  0,    0,   0,   0    ; MD_ACC   A
      .byte DK_BYTE, '#', '$',   0,   0,   0    ; MD_IMM   #$nn
      .byte DK_BYTE, '$',  0,    0,   0,   0    ; MD_ZP    $nn
      .byte DK_BYTE, '$',  0,   ',', 'X',  0    ; MD_ZPX   $nn,X
      .byte DK_BYTE, '$',  0,   ',', 'Y',  0    ; MD_ZPY   $nn,Y
      .byte DK_WORD, '$',  0,    0,   0,   0    ; MD_ABS   $nnnn
      .byte DK_WORD, '$',  0,   ',', 'X',  0    ; MD_ABX   $nnnn,X
      .byte DK_WORD, '$',  0,   ',', 'Y',  0    ; MD_ABY   $nnnn,Y
      .byte DK_WORD, '(', '$',  ')',  0,   0    ; MD_IND   ($nnnn)
      .byte DK_BYTE, '(', '$',  ',', 'X', ')'   ; MD_IZX   ($nn,X)
      .byte DK_BYTE, '(', '$',  ')', ',', 'Y'   ; MD_IZY   ($nn),Y
      .byte DK_BYTE, '(', '$',  ')',  0,   0    ; MD_IZP   ($nn)
      .byte DK_WORD, '(', '$',  ',', 'X', ')'   ; MD_AIX   ($nnnn,X)
      .byte DK_REL,  '$',  0,    0,   0,   0    ; MD_REL   $nnnn
      .byte DK_ZPREL,'$',  0,    0,   0,   0    ; MD_ZPR   $nn,$nnnn

; ---------------------------------------------------------------------------
; DASM start[,count]
;
; Entered from the LAB_CTBL dispatch with LAB_IGBY already done, so A holds the
; byte after the token with the flags set on it.
; ---------------------------------------------------------------------------

LAB_DASM
      JSR   LAB_EVNM          ; evaluate the start address
      JSR   LAB_F2FX          ; fix it into Itempl/Itemph
      LDA   Itempl
      STA   ASM_LC
      LDA   Itemph
      STA   ASM_LC+1

      LDX   #DASM_DEFAULT     ; the count is optional
      JSR   LAB_GBYT          ; anything left on the line?
      BEQ   @go               ; no, take the default

      JSR   LAB_1C01          ; scan for "," else syntax error
      JSR   LAB_GTBY          ; get the count in X
      CPX   #$00
      BEQ   @done             ; a count of zero prints nothing

@go
      STX   ASM_CNT
@loop
      JSR   DASM_ONE          ; one instruction, advancing ASM_LC
      DEC   ASM_CNT
      BNE   @loop

@done
      RTS

; ---------------------------------------------------------------------------
; DASM_ONE   disassemble the instruction at ASM_LC, then step ASM_LC past it
;
; Prints "AAAA  HH HH HH  MNE OPERAND". The hex column is padded to three byte
; slots so the mnemonics line up whatever the instruction length is.
; ---------------------------------------------------------------------------

DASM_ONE
      LDA   ASM_LC+1          ; address column
      JSR   DASM_HEX
      LDA   ASM_LC
      JSR   DASM_HEX
      JSR   DASM_SP2

      LDY   #$00
      LDA   (ASM_LC),Y        ; the opcode
      TAX
      LDA   OPMODE,X
      STA   ASM_MOD
      LDA   OPMNEM,X
      STA   ASM_MNI

      LDA   ASM_MOD           ; length is the high nibble of the mode byte
      LSR
      LSR
      LSR
      LSR
      STA   ASM_CNT+1         ; bytes in this instruction

; the hex bytes, then blanks out to three slots

      LDY   #$00
@hex
      CPY   ASM_CNT+1
      BCS   @pad

      LDA   (ASM_LC),Y
      JSR   DASM_HEX
      LDA   #' '
      JSR   LAB_PRNA
      INY
      BRA   @hex

@pad
      CPY   #$03
      BCS   @mnem

      JSR   DASM_SP2
      LDA   #' '
      JSR   LAB_PRNA
      INY
      BRA   @pad

@mnem
      JSR   DASM_SP2
      JSR   DASM_NAME         ; the mnemonic, plus a bit digit if it takes one
      LDA   ASM_MNI
      BEQ   @next             ; MN_ILL has no operand to print

      LDA   ASM_MOD           ; nor does implied, and it must not get the
      AND   #MD_MODE          ; separating space either or every line of a
      BEQ   @next             ; listing would end in one

      LDA   #' '
      JSR   LAB_PRNA
      JSR   DASM_OPERAND

@next
      JSR   LAB_CRLF          ; ends the line and resets the column count

      CLC                     ; step past the instruction
      LDA   ASM_LC
      ADC   ASM_CNT+1
      STA   ASM_LC
      BCC   @out

      INC   ASM_LC+1
@out
      RTS

; ---------------------------------------------------------------------------
; DASM_NAME   print the mnemonic named by ASM_MNI
;
; Three letters unpacked from OPNAME, five bits each. MN_BBR through MN_SMB
; carry a bit number in the opcode rather than in the name, so those four get
; the digit from bits 4 to 6 of the opcode printed after them.
; ---------------------------------------------------------------------------

DASM_NAME
      LDA   ASM_MNI
      BNE   @known

      LDA   #'?'              ; not an instruction on the selected CPU
      JSR   LAB_PRNA
      JSR   LAB_PRNA
      JMP   LAB_PRNA

@known
      ASL                     ; two bytes per name
      TAY
      LDA   OPNAME,Y
      STA   ASM_MNE
      LDA   OPNAME+1,Y
      STA   ASM_MNE+1

      LDX   #$00              ; letters run high bits first
@letter
      JSR   DASM_LETTER
      INX
      CPX   #$03
      BNE   @letter

      LDA   ASM_MNI           ; does this one carry a bit number
      CMP   #MN_SMB+1
      BCS   @noBit            ; above the four that do

      LDY   #$00
      LDA   (ASM_LC),Y        ; bit number is opcode bits 4-6
      LSR
      LSR
      LSR
      LSR
      AND   #$07
      ORA   #'0'
      JMP   LAB_PRNA

@noBit
      RTS

; shift the top five bits out of ASM_MNE and print them as a letter

DASM_LETTER
      LDY   #$05
      LDA   #$00
@shift
      ASL   ASM_MNE
      ROL   ASM_MNE+1
      ROL
      DEY
      BNE   @shift

      AND   #$1F
      ORA   #$40              ; 1 = "A"
      JMP   LAB_PRNA

; ---------------------------------------------------------------------------
; DASM_OPERAND   print the operand for the mode in ASM_MOD
; ---------------------------------------------------------------------------

DASM_OPERAND
      LDA   ASM_MOD
      AND   #MD_MODE
      STA   ASM_TMP           ; mode number
      ASL                     ; six bytes per row
      ASL
      CLC
      ADC   ASM_TMP
      ADC   ASM_TMP
      TAY                     ; Y indexes MODEFMT

      LDA   MODEFMT,Y         ; kind
      STA   ASM_TMP+1
      INY
      JSR   DASM_EMIT         ; up to two prefix characters
      JSR   DASM_EMIT

      LDA   ASM_TMP+1
      BEQ   @post             ; DK_NONE, nothing between

      CMP   #DK_BYTE
      BEQ   @byte

      CMP   #DK_WORD
      BEQ   @word

      CMP   #DK_REL
      BEQ   @rel

; DK_ZPREL, "$nn,$nnnn" - the zero page byte, then a branch target measured
; from the byte after the whole three byte instruction

      PHY
      LDY   #$01
      LDA   (ASM_LC),Y
      JSR   DASM_HEX
      LDA   #','
      JSR   LAB_PRNA
      LDA   #'$'
      JSR   LAB_PRNA
      LDY   #$02
      LDA   (ASM_LC),Y
      JSR   DASM_TARGET
      PLY
      BRA   @post

@byte
      PHY
      LDY   #$01
      LDA   (ASM_LC),Y
      JSR   DASM_HEX
      PLY
      BRA   @post

@word
      PHY
      LDY   #$02
      LDA   (ASM_LC),Y        ; high byte first
      JSR   DASM_HEX
      DEY
      LDA   (ASM_LC),Y
      JSR   DASM_HEX
      PLY
      BRA   @post

@rel
      PHY
      LDY   #$01
      LDA   (ASM_LC),Y
      JSR   DASM_TARGET
      PLY

@post
      JSR   DASM_EMIT         ; up to three suffix characters
      JSR   DASM_EMIT
      JMP   DASM_EMIT

; print the character at MODEFMT,Y unless it is $00, then step Y on

DASM_EMIT
      LDA   MODEFMT,Y
      INY
      CMP   #$00
      BEQ   @skip

      JMP   LAB_PRNA

@skip
      RTS

; ---------------------------------------------------------------------------
; DASM_TARGET   A holds a signed branch offset. Print the address it lands on,
;               which is ASM_LC plus the instruction length plus the offset.
; ---------------------------------------------------------------------------

DASM_TARGET
      TAX                     ; keep the offset
      AND   #$80              ; sign extend it into ASM_TMP+1
      BEQ   @pos

      LDA   #$FF
@pos
      STA   ASM_TMP+1
      STX   ASM_TMP

      CLC
      LDA   ASM_LC
      ADC   ASM_CNT+1         ; past the instruction first
      STA   ASM_VAL
      LDA   ASM_LC+1
      ADC   #$00
      STA   ASM_VAL+1

      CLC
      LDA   ASM_VAL
      ADC   ASM_TMP
      STA   ASM_VAL
      LDA   ASM_VAL+1
      ADC   ASM_TMP+1

      JSR   DASM_HEX          ; high byte
      LDA   ASM_VAL
      JMP   DASM_HEX

; ---------------------------------------------------------------------------
; small output helpers
; ---------------------------------------------------------------------------

; print A as two hex digits

DASM_HEX
      PHA
      LSR
      LSR
      LSR
      LSR
      JSR   @digit
      PLA
@digit
      AND   #$0F
      CMP   #$0A
      BCC   @out

      ADC   #$06              ; carry is set here, so this adds seven
@out
      ADC   #'0'
      JMP   LAB_PRNA

; two spaces, the gap between columns

DASM_SP2
      LDA   #' '
      JSR   LAB_PRNA
      LDA   #' '
      JMP   LAB_PRNA
