; Opcode and mnemonic tables for the inline assembler and the disassembler.
;
; ASM_CPU picks which instruction set they cover:
;
;   0   NMOS 6502, the original 151 opcodes
;   1   65C02 core - adds BRA, PHX/PHY/PLX/PLY, STZ, TRB/TSB, INC A/DEC A,
;       BIT #imm, BIT zp,X, BIT abs,X, JMP (abs,X) and the (zp) modes. 178
;   2   full WDC W65C02S - adds RMB0-7, SMB0-7, BBR0-7, BBS0-7, WAI, STP. 212
;
; 2 is the default, because that is the part the board carries. A Rockwell
; R65C02 has the bit instructions but not WAI or STP, and a GTE/CMD G65SC02
; has neither, so build those with "make ASMCPU=1". Nothing here can tell what
; the silicon actually is - the flag is the only guard.
;
; THIS FILE IS DERIVED, NOT TYPED. The 256 entries below were generated from a
; cross check of two independent opcode tables rather than transcribed by hand,
; which is the one way to get a table this size right without a test suite.
; The rows are laid out sixteen to a line group so they can still be diffed by
; eye against a printed opcode matrix.

; Included by assembler.s, which has already settled ASM_BUILT and
; ASM_CPU_SEL and selected the CODE segment.

; ---------------------------------------------------------------------------
; addressing modes
;
; the instruction length lives in the high nibble of the mode constant. that
; costs nothing to store and saves a second table, and a lookup in it, in both
; the assembler and the disassembler - the mode byte answers "how do I parse
; this" and "how many bytes is it" at the same time
; ---------------------------------------------------------------------------

MD_IMP       = $10            ; 1 byte , implied
MD_ACC       = $11            ; 1 byte , accumulator, "A" or nothing
MD_IMM       = $22            ; 2 bytes, #nn
MD_ZP        = $23            ; 2 bytes, nn
MD_ZPX       = $24            ; 2 bytes, nn,X
MD_ZPY       = $25            ; 2 bytes, nn,Y
MD_ABS       = $36            ; 3 bytes, nnnn
MD_ABX       = $37            ; 3 bytes, nnnn,X
MD_ABY       = $38            ; 3 bytes, nnnn,Y
MD_IND       = $39            ; 3 bytes, (nnnn)          JMP only
MD_IZX       = $2A            ; 2 bytes, (nn,X)
MD_IZY       = $2B            ; 2 bytes, (nn),Y
MD_IZP       = $2C            ; 2 bytes, (nn)            65C02
MD_AIX       = $3D            ; 3 bytes, (nnnn,X)        65C02 JMP
MD_REL       = $2E            ; 2 bytes, branch target
MD_ZPR       = $3F            ; 3 bytes, nn,target       WDC BBR/BBS

MD_MODE      = $0F            ; mask for the mode number
MD_LEN       = $F0            ; mask for the length

; ---------------------------------------------------------------------------
; mnemonic indices
;
; MN_ILL stays at 0 so that an unimplemented opcode can never match a real
; mnemonic, and the four bit numbered WDC instructions are next so that "does
; this one take a bit number?" is a single compare against MN_SMB. RMB0-7 and
; friends are one mnemonic each, not eight - the bit is (opcode >> 4) & 7
; ---------------------------------------------------------------------------

MN_ILL        =   0
MN_BBR        =   1
MN_BBS        =   2
MN_RMB        =   3
MN_SMB        =   4
MN_ADC        =   5
MN_AND        =   6
MN_ASL        =   7
MN_BCC        =   8
MN_BCS        =   9
MN_BEQ        =  10
MN_BIT        =  11
MN_BMI        =  12
MN_BNE        =  13
MN_BPL        =  14
MN_BRA        =  15
MN_BRK        =  16
MN_BVC        =  17
MN_BVS        =  18
MN_CLC        =  19
MN_CLD        =  20
MN_CLI        =  21
MN_CLV        =  22
MN_CMP        =  23
MN_CPX        =  24
MN_CPY        =  25
MN_DEC        =  26
MN_DEX        =  27
MN_DEY        =  28
MN_EOR        =  29
MN_INC        =  30
MN_INX        =  31
MN_INY        =  32
MN_JMP        =  33
MN_JSR        =  34
MN_LDA        =  35
MN_LDX        =  36
MN_LDY        =  37
MN_LSR        =  38
MN_NOP        =  39
MN_ORA        =  40
MN_PHA        =  41
MN_PHP        =  42
MN_PHX        =  43
MN_PHY        =  44
MN_PLA        =  45
MN_PLP        =  46
MN_PLX        =  47
MN_PLY        =  48
MN_ROL        =  49
MN_ROR        =  50
MN_RTI        =  51
MN_RTS        =  52
MN_SBC        =  53
MN_SEC        =  54
MN_SED        =  55
MN_SEI        =  56
MN_STA        =  57
MN_STP        =  58
MN_STX        =  59
MN_STY        =  60
MN_STZ        =  61
MN_TAX        =  62
MN_TAY        =  63
MN_TRB        =  64
MN_TSB        =  65
MN_TSX        =  66
MN_TXA        =  67
MN_TXS        =  68
MN_TYA        =  69
MN_WAI        =  70

MN_COUNT     = 71

; ---------------------------------------------------------------------------
; mnemonic names, three letters packed 5 bits each and left aligned, so the
; letters occupy bits 15-11, 10-6 and 5-1. left aligned because the unpacker
; shifts the top bit out sixteen times rather than masking from the bottom.
; letter = value + '@', so 1 = "A" .. 26 = "Z"
; ---------------------------------------------------------------------------

OPNAME
      .word $4B18            ; ILL
      .word $10A4            ; BBR
      .word $10A6            ; BBS
      .word $9344            ; RMB
      .word $9B44            ; SMB
      .word $0906            ; ADC
      .word $0B88            ; AND
      .word $0CD8            ; ASL
      .word $10C6            ; BCC
      .word $10E6            ; BCS
      .word $1162            ; BEQ
      .word $1268            ; BIT
      .word $1352            ; BMI
      .word $138A            ; BNE
      .word $1418            ; BPL
      .word $1482            ; BRA
      .word $1496            ; BRK
      .word $1586            ; BVC
      .word $15A6            ; BVS
      .word $1B06            ; CLC
      .word $1B08            ; CLD
      .word $1B12            ; CLI
      .word $1B2C            ; CLV
      .word $1B60            ; CMP
      .word $1C30            ; CPX
      .word $1C32            ; CPY
      .word $2146            ; DEC
      .word $2170            ; DEX
      .word $2172            ; DEY
      .word $2BE4            ; EOR
      .word $4B86            ; INC
      .word $4BB0            ; INX
      .word $4BB2            ; INY
      .word $5360            ; JMP
      .word $54E4            ; JSR
      .word $6102            ; LDA
      .word $6130            ; LDX
      .word $6132            ; LDY
      .word $64E4            ; LSR
      .word $73E0            ; NOP
      .word $7C82            ; ORA
      .word $8202            ; PHA
      .word $8220            ; PHP
      .word $8230            ; PHX
      .word $8232            ; PHY
      .word $8302            ; PLA
      .word $8320            ; PLP
      .word $8330            ; PLX
      .word $8332            ; PLY
      .word $93D8            ; ROL
      .word $93E4            ; ROR
      .word $9512            ; RTI
      .word $9526            ; RTS
      .word $9886            ; SBC
      .word $9946            ; SEC
      .word $9948            ; SED
      .word $9952            ; SEI
      .word $9D02            ; STA
      .word $9D20            ; STP
      .word $9D30            ; STX
      .word $9D32            ; STY
      .word $9D34            ; STZ
      .word $A070            ; TAX
      .word $A072            ; TAY
      .word $A484            ; TRB
      .word $A4C4            ; TSB
      .word $A4F0            ; TSX
      .word $A602            ; TXA
      .word $A626            ; TXS
      .word $A642            ; TYA
      .word $B852            ; WAI

; ---------------------------------------------------------------------------
; the opcode map
;
; one declarative list, expanded twice, so the mnemonic and mode tables can
; never drift apart. lvl is the lowest ASM_CPU that has the instruction, and
; anything above the selected level is blanked to MN_ILL so that it fails
; cleanly rather than assembling something the CPU cannot run
; ---------------------------------------------------------------------------

; which of the two tables is being emitted is held in a redefinable symbol
; rather than passed down as a macro argument, because ca65 will not resolve a
; macro parameter through a nested macro call

OPSEL        .set 0           ; 0 emits mnemonics, 1 emits modes

.macro OPC mn, md, lvl
      .if lvl <= ASM_CPU_SEL
            .if OPSEL = 0
                  .byte mn
            .else
                  .byte md
            .endif
      .else
            .if OPSEL = 0
                  .byte MN_ILL
            .else
                  .byte MD_IMP
            .endif
      .endif
.endmacro

.macro OPTABLE
      ; $0x
      OPC MN_BRK, MD_IMP, 0
      OPC MN_ORA, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_TSB, MD_ZP, 1
      OPC MN_ORA, MD_ZP, 0
      OPC MN_ASL, MD_ZP, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_PHP, MD_IMP, 0
      OPC MN_ORA, MD_IMM, 0
      OPC MN_ASL, MD_ACC, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_TSB, MD_ABS, 1
      OPC MN_ORA, MD_ABS, 0
      OPC MN_ASL, MD_ABS, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $1x
      OPC MN_BPL, MD_REL, 0
      OPC MN_ORA, MD_IZY, 0
      OPC MN_ORA, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_TRB, MD_ZP, 1
      OPC MN_ORA, MD_ZPX, 0
      OPC MN_ASL, MD_ZPX, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_CLC, MD_IMP, 0
      OPC MN_ORA, MD_ABY, 0
      OPC MN_INC, MD_ACC, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_TRB, MD_ABS, 1
      OPC MN_ORA, MD_ABX, 0
      OPC MN_ASL, MD_ABX, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $2x
      OPC MN_JSR, MD_ABS, 0
      OPC MN_AND, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_BIT, MD_ZP, 0
      OPC MN_AND, MD_ZP, 0
      OPC MN_ROL, MD_ZP, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_PLP, MD_IMP, 0
      OPC MN_AND, MD_IMM, 0
      OPC MN_ROL, MD_ACC, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_BIT, MD_ABS, 0
      OPC MN_AND, MD_ABS, 0
      OPC MN_ROL, MD_ABS, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $3x
      OPC MN_BMI, MD_REL, 0
      OPC MN_AND, MD_IZY, 0
      OPC MN_AND, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_BIT, MD_ZPX, 1
      OPC MN_AND, MD_ZPX, 0
      OPC MN_ROL, MD_ZPX, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_SEC, MD_IMP, 0
      OPC MN_AND, MD_ABY, 0
      OPC MN_DEC, MD_ACC, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_BIT, MD_ABX, 1
      OPC MN_AND, MD_ABX, 0
      OPC MN_ROL, MD_ABX, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $4x
      OPC MN_RTI, MD_IMP, 0
      OPC MN_EOR, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_EOR, MD_ZP, 0
      OPC MN_LSR, MD_ZP, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_PHA, MD_IMP, 0
      OPC MN_EOR, MD_IMM, 0
      OPC MN_LSR, MD_ACC, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_JMP, MD_ABS, 0
      OPC MN_EOR, MD_ABS, 0
      OPC MN_LSR, MD_ABS, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $5x
      OPC MN_BVC, MD_REL, 0
      OPC MN_EOR, MD_IZY, 0
      OPC MN_EOR, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_EOR, MD_ZPX, 0
      OPC MN_LSR, MD_ZPX, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_CLI, MD_IMP, 0
      OPC MN_EOR, MD_ABY, 0
      OPC MN_PHY, MD_IMP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_EOR, MD_ABX, 0
      OPC MN_LSR, MD_ABX, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $6x
      OPC MN_RTS, MD_IMP, 0
      OPC MN_ADC, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STZ, MD_ZP, 1
      OPC MN_ADC, MD_ZP, 0
      OPC MN_ROR, MD_ZP, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_PLA, MD_IMP, 0
      OPC MN_ADC, MD_IMM, 0
      OPC MN_ROR, MD_ACC, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_JMP, MD_IND, 0
      OPC MN_ADC, MD_ABS, 0
      OPC MN_ROR, MD_ABS, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $7x
      OPC MN_BVS, MD_REL, 0
      OPC MN_ADC, MD_IZY, 0
      OPC MN_ADC, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STZ, MD_ZPX, 1
      OPC MN_ADC, MD_ZPX, 0
      OPC MN_ROR, MD_ZPX, 0
      OPC MN_RMB, MD_ZP, 2
      OPC MN_SEI, MD_IMP, 0
      OPC MN_ADC, MD_ABY, 0
      OPC MN_PLY, MD_IMP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_JMP, MD_AIX, 1
      OPC MN_ADC, MD_ABX, 0
      OPC MN_ROR, MD_ABX, 0
      OPC MN_BBR, MD_ZPR, 2
      ; $8x
      OPC MN_BRA, MD_REL, 1
      OPC MN_STA, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STY, MD_ZP, 0
      OPC MN_STA, MD_ZP, 0
      OPC MN_STX, MD_ZP, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_DEY, MD_IMP, 0
      OPC MN_BIT, MD_IMM, 1
      OPC MN_TXA, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STY, MD_ABS, 0
      OPC MN_STA, MD_ABS, 0
      OPC MN_STX, MD_ABS, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $9x
      OPC MN_BCC, MD_REL, 0
      OPC MN_STA, MD_IZY, 0
      OPC MN_STA, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STY, MD_ZPX, 0
      OPC MN_STA, MD_ZPX, 0
      OPC MN_STX, MD_ZPY, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_TYA, MD_IMP, 0
      OPC MN_STA, MD_ABY, 0
      OPC MN_TXS, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_STZ, MD_ABS, 1
      OPC MN_STA, MD_ABX, 0
      OPC MN_STZ, MD_ABX, 1
      OPC MN_BBS, MD_ZPR, 2
      ; $Ax
      OPC MN_LDY, MD_IMM, 0
      OPC MN_LDA, MD_IZX, 0
      OPC MN_LDX, MD_IMM, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_LDY, MD_ZP, 0
      OPC MN_LDA, MD_ZP, 0
      OPC MN_LDX, MD_ZP, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_TAY, MD_IMP, 0
      OPC MN_LDA, MD_IMM, 0
      OPC MN_TAX, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_LDY, MD_ABS, 0
      OPC MN_LDA, MD_ABS, 0
      OPC MN_LDX, MD_ABS, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $Bx
      OPC MN_BCS, MD_REL, 0
      OPC MN_LDA, MD_IZY, 0
      OPC MN_LDA, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_LDY, MD_ZPX, 0
      OPC MN_LDA, MD_ZPX, 0
      OPC MN_LDX, MD_ZPY, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_CLV, MD_IMP, 0
      OPC MN_LDA, MD_ABY, 0
      OPC MN_TSX, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_LDY, MD_ABX, 0
      OPC MN_LDA, MD_ABX, 0
      OPC MN_LDX, MD_ABY, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $Cx
      OPC MN_CPY, MD_IMM, 0
      OPC MN_CMP, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_CPY, MD_ZP, 0
      OPC MN_CMP, MD_ZP, 0
      OPC MN_DEC, MD_ZP, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_INY, MD_IMP, 0
      OPC MN_CMP, MD_IMM, 0
      OPC MN_DEX, MD_IMP, 0
      OPC MN_WAI, MD_IMP, 2
      OPC MN_CPY, MD_ABS, 0
      OPC MN_CMP, MD_ABS, 0
      OPC MN_DEC, MD_ABS, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $Dx
      OPC MN_BNE, MD_REL, 0
      OPC MN_CMP, MD_IZY, 0
      OPC MN_CMP, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_CMP, MD_ZPX, 0
      OPC MN_DEC, MD_ZPX, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_CLD, MD_IMP, 0
      OPC MN_CMP, MD_ABY, 0
      OPC MN_PHX, MD_IMP, 1
      OPC MN_STP, MD_IMP, 2
      OPC MN_ILL, MD_IMP, 0
      OPC MN_CMP, MD_ABX, 0
      OPC MN_DEC, MD_ABX, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $Ex
      OPC MN_CPX, MD_IMM, 0
      OPC MN_SBC, MD_IZX, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_CPX, MD_ZP, 0
      OPC MN_SBC, MD_ZP, 0
      OPC MN_INC, MD_ZP, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_INX, MD_IMP, 0
      OPC MN_SBC, MD_IMM, 0
      OPC MN_NOP, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_CPX, MD_ABS, 0
      OPC MN_SBC, MD_ABS, 0
      OPC MN_INC, MD_ABS, 0
      OPC MN_BBS, MD_ZPR, 2
      ; $Fx
      OPC MN_BEQ, MD_REL, 0
      OPC MN_SBC, MD_IZY, 0
      OPC MN_SBC, MD_IZP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_SBC, MD_ZPX, 0
      OPC MN_INC, MD_ZPX, 0
      OPC MN_SMB, MD_ZP, 2
      OPC MN_SED, MD_IMP, 0
      OPC MN_SBC, MD_ABY, 0
      OPC MN_PLX, MD_IMP, 1
      OPC MN_ILL, MD_IMP, 0
      OPC MN_ILL, MD_IMP, 0
      OPC MN_SBC, MD_ABX, 0
      OPC MN_INC, MD_ABX, 0
      OPC MN_BBS, MD_ZPR, 2
.endmacro

OPSEL        .set 0
OPMNEM
      OPTABLE

OPSEL        .set 1
OPMODE
      OPTABLE

; ---------------------------------------------------------------------------
; ASM_FINDOP   mnemonic index in ASM_MNI, wanted mode byte in A
;              returns the opcode in X with carry set, or carry clear
;
; The loop index is the opcode, so the same two tables that let the
; disassembler go opcode -> mnemonic let the assembler go the other way with
; no reverse index at all. The mode byte already carries the length, so the
; whole byte is compared in one go and there is no masking in the loop.
;
; 256 passes of about 11 cycles is under 3ms at 1MHz, and only pass 2 does it -
; pass 1 gets the instruction length straight out of the mode byte
; ---------------------------------------------------------------------------

ASM_FINDOP
      STA   ASM_TMP           ; hold the wanted mode
      LDX   #$00
@loop
      LDA   OPMNEM,X          ; mnemonic for this opcode
      CMP   ASM_MNI
      BNE   @next

      LDA   OPMODE,X          ; right mnemonic, is it the right mode
      CMP   ASM_TMP
      BEQ   @found            ; yes, X is the opcode and carry is set

@next
      INX
      BNE   @loop             ; 256 passes, ends with X = 0

      CLC                     ; no such mnemonic and mode pair
@found
      RTS
