; Inline 6502/65C02 assembler for EhBASIC.
;
; The token tables live in basic.s (the TK_* equates, LAB_CTBL, TAB_ASCx,
; LAB_KEYT, LAB_FTPL and LAB_FTBL), so the edits there are table entries only
; and the code that runs sits here. The opcode tables are in opcodes.s and the
; disassembler is in disasm.s.
;
; Source is written as ordinary numbered BASIC lines between ASM and ENDASM:
;
;   100 ASM
;   110 START LDA MSG,X
;   120       BEQ DONE
;   130       JSR $FFD2
;   140 DONE  RTS
;   150 MSG   TEXT "HELLO"
;   160 ENDASM
;   170 CALL SYM("START")
;
; Those lines are crunched into tokens like any other BASIC line, so what is
; actually stored for line 120 is BEQ <TK_DO> NE, not the text that was typed.
; That is deliberate. The obvious alternative - stopping the tokenizer inside a
; block, the way DATA and REM do - cannot work, because Oquote resets at end of
; line and lines are crunched one at a time as they are typed. Enter line 130
; after the fact, or edit it, and the tokenizer has no idea it sits inside a
; block.
;
; The crunch is lossless, because LIST has to reproduce lines exactly, so the
; assembler simply expands each line back into plain ASCII before parsing it
; (see asm_expand below). basic.s's tokenizer is left alone, entry order and
; editing are immaterial, and LIST is correct for free.

; ASM_BUILT and ASM_CPU_SEL are worked out in min_mon.s, which settles them
; before its include of basic.s. This is a separate assembly unit, so it has to
; work them out for itself, and the two must agree - which they do, because the
; Makefile passes the same -D to both

.ifdef ASM_ENABLE
ASM_BUILT = ASM_ENABLE
.else
ASM_BUILT = 1
.endif

; which instruction set the opcode tables in opcodes.s cover.
; 0 = NMOS 6502, 1 = 65C02 core, 2 = full WDC W65C02S

.ifdef ASM_CPU
ASM_CPU_SEL = ASM_CPU
.else
ASM_CPU_SEL = 2
.endif

.if ASM_BUILT

      .export LAB_ASM, LAB_ENDASM, LAB_ASSEMBLE, LAB_DASM, LAB_SYM

; EhBASIC internals, exported from min_mon.s below its include of basic.s
;
;   LAB_GTBY   get byte parameter, result in X
;   LAB_EVNM   evaluate numeric expression
;   LAB_F2FX   FAC1 float to fixed, result in Itempl/h and in AY
;   LAB_AYFC   signed 16 bit AY to FAC1
;   LAB_22B6   pop a string descriptor, A = length, pointer in ut1_pl
;   LAB_18C3   print null terminated string from AY
;   LAB_295E   print XA as an unsigned integer
;   LAB_XERR   raise error number X and warm start
;   LAB_1C01   scan for "," else syntax error
;   LAB_PRNA   print the character in A, keeping the column count right
;   LAB_CRLF   new line, which is also what resets that count
;   LAB_147A   the body of CLEAR
;   LAB_KEYT   the LIST keyword table, walked by asm_expand
;   LAB_IGBY   increment the execute pointer and scan
;   LAB_GBYT   scan at the execute pointer, Z set at end of statement

      .import LAB_GTBY, LAB_EVNM, LAB_EVEX, LAB_22B6
      .import LAB_F2FX, LAB_AYFC, LAB_18C3, LAB_295E, LAB_XERR
      .import LAB_1C01, LAB_147A, LAB_KEYT, LAB_PRNA, LAB_CRLF
      .importzp TK_ASM, TK_ENDASM

      .importzp LAB_IGBY, LAB_GBYT, Dtypef, ut1_pl, ASM_FLG, Clinel
      .importzp Smeml, Svarl, Earryl, Sstorl, Ememl, Bpntrl, Itempl

; only the low bytes are imported, the high bytes follow them in page zero

Smemh        = Smeml+1
Svarh        = Svarl+1
Earryh       = Earryl+1
Sstorh       = Sstorl+1
Ememh        = Ememl+1
Bpntrh       = Bpntrl+1
Itemph       = Itempl+1
Clineh       = Clinel+1

; error codes, matching the LAB_BAER table in basic.s

; An optional prefix, allowed as the first non space character of a line
; inside a block, whose only job is to stop EhBASIC eating the indentation
; after it. LAB_GFPN leaves the execute pointer past any spaces following the
; line number, so "110       LDA #$00" is stored, and LISTs, with the spaces
; gone. Anything non blank at that position stops the skipping, and this is a
; character with no meaning anywhere else: the tokenizer copies it straight
; through, it costs no token, and outside a block it is a syntax error, which
; is what a stray one should be.

ASM_INDENT   = '|'

ERRNUM_ASM   = $24            ; "Assembly syntax"
ERRNUM_UL    = $26            ; "Undefined label"
ERRNUM_DL    = $28            ; "Duplicate label"
ERRNUM_BR    = $2A            ; "Branch out of range"
ERRNUM_BLK   = $2C            ; "ASM block"

; ---------------------------------------------------------------------------
; zero page
;
; taken from EhBASIC's unused $13-$5A, below the $24-$2B that wozmon.s holds.
; nothing here has to survive a warm start, it is all working storage for the
; two passes, but ASM_TOP and ASM_BASE do have to survive from one assembly to
; the next so that SYM() still works and so that a re-assemble does not reserve
; memory a second time
; ---------------------------------------------------------------------------

; $2C is ASM_FLG, declared in min_mon.s because basic.s clears it

; kept between statements, so that SYM() still works and so that a second
; assembly does not reserve memory all over again

ASM_BAS      = $2D            ; image base, low/high
ASM_SIZ      = $2F            ; image size, low/high
ASM_SYM      = $31            ; symbol table base, low/high
ASM_NSY      = $33            ; symbols defined
ASM_OEM      = $34            ; Ememl as it was before any reservation

; live only while an assembly or a disassembly is running

ASM_LC       = $36            ; location counter, low/high
ASM_PAS      = $38            ; pass number, 1 or 2
ASM_REL      = $39            ; $80 relocatable, $00 absolute (after ORG)
ASM_LPT      = $3A            ; the line header being assembled, low/high
ASM_BUF      = $3C            ; index into the expanded line
ASM_VAL      = $3D            ; parsed operand value, low/high
ASM_MOD      = $3F            ; (length << 4) | addressing mode
ASM_MNE      = $40            ; packed mnemonic, low/high
ASM_MNI      = $42            ; mnemonic index
ASM_BIT      = $43            ; bit number for RMB/SMB/BBR/BBS
ASM_TMP      = $44            ; general scratch, low/high
ASM_SPT      = $46            ; symbol table walk pointer, low/high
                              ; $48-$49 free
ASM_SLN      = $4A            ; symbol table bottom during pass 1, low/high
ASM_CNT      = $4C            ; byte counter
ASM_LST      = $4D            ; non zero while the listing is wanted
ASM_QUO      = $4E            ; expander quote state
ASM_WRK      = $4F            ; expanded line buffer address, low/high
ASM_FS       = $52            ; start of the current field in the line buffer
ASM_FL       = $53            ; and its length
ASM_OPC      = $54            ; opcode being emitted
ASM_T2       = $55            ; two more scratch bytes, used where a compare
ASM_T3       = $56            ; needs an index into each of two buffers
ASM_LC0      = $57            ; location counter as the line started, so the
                              ; listing knows which bytes this line produced
ASM_INB      = $51            ; $80 while the walk is inside an ASM block.
                              ; deliberately not ASM_TMP - the line expander
                              ; uses that as its keyword table pointer, and a
                              ; single tokenised line would wipe the state
                              ; $59-$5A spare

; ASM_FLG values

ASMF_VALID   = $80            ; an image has been assembled and is still good

      .segment "CODE"

; ---------------------------------------------------------------------------
; ASM
;
; Reached when the interpreter walks into the top of a block. If the image is
; still good this just steps over the block to the line after its ENDASM. If it
; is stale it assembles the whole program first.
; ---------------------------------------------------------------------------

LAB_ASM
      LDX   Clineh            ; $FF here means immediate mode, and there is no
      INX                     ; line for a block to be part of. without this
      BNE   asm_in_prog       ; the walk below has nothing sane to start from

      LDX   #$16              ; "Illegal direct"
      JMP   LAB_XERR

asm_in_prog
      LDA   ASM_FLG           ; is there a good image already
      BMI   asm_skip          ; yes, just step over the block

      LDA   #$00              ; no listing for an assembly nobody asked for
      STA   ASM_LST
      JSR   ASM_DRIVER        ; go build one

; the block still has to be stepped over. walk the line chain from the line
; being executed until a line whose first token is ENDASM, then leave the
; execute pointer on that line's terminating null. the interpreter's inner
; loop reads the null, moves to the following line and picks up its number by
; itself, so Clinel and Clineh need no help from here

asm_skip
      JSR   ASM_THISLINE      ; ASM_LPT = the header of the line we are on
asm_skip_lp
      JSR   ASM_NEXTLINE      ; step to the next line
      BCC   asm_noend         ; ran off the end of the program

      JSR   ASM_FIRSTTOK      ; first token of that line
      CMP   #TK_ENDASM
      BNE   asm_skip_lp

      LDY   #$00              ; found it. the execute pointer goes to this
      LDA   (ASM_LPT),Y       ; line's terminator, which is its own link
      SEC                     ; address minus one, exactly as LAB_GOTO does
      SBC   #$01
      STA   Bpntrl
      INY
      LDA   (ASM_LPT),Y
      SBC   #$00
      STA   Bpntrh
      RTS

asm_noend
      LDX   #ERRNUM_BLK       ; ASM with no ENDASM below it
      JMP   ASM_ERROR

; ---------------------------------------------------------------------------
; ENDASM
;
; Never reached in a well formed program - ASM steps over its own ENDASM - so
; getting here means an ENDASM with no ASM above it.
; ---------------------------------------------------------------------------

LAB_ENDASM
      LDX   #ERRNUM_BLK
      JMP   LAB_XERR          ; not ASM_ERROR - no assembly is running, so
                              ; ASM_LPT names no line and would report a
                              ; nonsense one. the interpreter's own Clineh is
                              ; already right here

; ---------------------------------------------------------------------------
; ASSEMBLE [n]
;
; Assemble the whole program now rather than waiting for a block to be reached.
; A non zero argument turns the listing on.
; ---------------------------------------------------------------------------

LAB_ASSEMBLE
      LDA   #$01              ; the listing is on unless told otherwise
      STA   ASM_LST
      JSR   LAB_GBYT          ; is there an argument
      BEQ   asm_ass_go

      JSR   LAB_GTBY          ; yes, get it, non zero means list
      STX   ASM_LST

asm_ass_go
      JSR   ASM_DRIVER
      JMP   ASM_REPORT        ; ASSEMBLE always says where the code went, even
                              ; with the listing off. lazy assembly does not,
                              ; it goes through ASM_DRIVER on its own

; ---------------------------------------------------------------------------
; ASM_DRIVER   assemble every ASM block in the program, in line order
;
; Two passes. Pass 1 sizes the image and collects the symbols, pass 2 emits.
; Between them the memory comes off the top of RAM and the symbols, which pass
; 1 recorded as offsets, are moved onto the base that gives.
; ---------------------------------------------------------------------------

ASM_DRIVER
      JSR   ASM_SETUP         ; reserve the working area, clear the symbols

      LDA   #$01
      STA   ASM_PAS
      JSR   ASM_WALK          ; pass 1

      JSR   ASM_ALLOC         ; now the size is known, place the image
      JSR   ASM_RELOC         ; and move the symbols onto its base

      LDA   #$02
      STA   ASM_PAS
      JSR   ASM_WALK          ; pass 2

      LDA   #ASMF_VALID
      STA   ASM_FLG
      RTS

; ---------------------------------------------------------------------------
; ASM_WALK   run one pass over the whole program
;
; Lines outside a block are skipped without being looked at beyond their first
; token, so ordinary BASIC between blocks costs almost nothing.
; ---------------------------------------------------------------------------

ASM_WALK
      JSR   ASM_RESETPC       ; location counter back to the start of the image
      JSR   ASM_FIRSTLINE
      LDA   #$00
      STA   ASM_INB           ; 0 = outside a block, $80 = inside one

asm_walk_lp
      JSR   ASM_ATEND
      BCS   asm_walk_end

      JSR   ASM_FIRSTTOK
      BIT   ASM_INB
      BMI   asm_walk_in

; outside a block

      CMP   #TK_ASM
      BEQ   asm_walk_open

      CMP   #TK_ENDASM        ; an ENDASM with no ASM above it
      BNE   asm_walk_next

      LDX   #ERRNUM_BLK
      JMP   ASM_ERROR

asm_walk_open
      LDA   #$80
      STA   ASM_INB
      BRA   asm_walk_next

; inside a block

asm_walk_in
      CMP   #TK_ENDASM
      BNE   asm_walk_line

      LDA   #$00
      STA   ASM_INB
      BRA   asm_walk_next

asm_walk_line
      JSR   ASM_EXPAND        ; crunched line back into plain text
      JSR   ASM_LINE          ; and assemble it

asm_walk_next
      JSR   ASM_NEXTLINE
      BCS   asm_walk_lp

asm_walk_end
      BIT   ASM_INB           ; a block left open at the end of the program
      BPL   asm_walk_ok

      LDX   #ERRNUM_BLK
      JMP   ASM_ERROR

asm_walk_ok
      RTS

; ---------------------------------------------------------------------------
; SYM($)
;
; Look a name up in the symbol table and return its address.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; walking the program
;
; A BASIC line is [link lo][link hi][number lo][number hi][tokens..][$00], so
; the first token sits at offset 4 and the link word is both "where the next
; line starts" and, minus one, "where this line's terminator is".
; ---------------------------------------------------------------------------

; ASM_LPT = the first line of the program

ASM_FIRSTLINE
      LDA   Smeml
      STA   ASM_LPT
      LDA   Smemh
      STA   ASM_LPT+1
      RTS

; ASM_LPT = the header of the line the interpreter is currently executing.
; Bpntr is somewhere inside that line, and Smeml.. is a linked list, so walk
; from the start until the next line's header is past Bpntr

ASM_THISLINE
      JSR   ASM_FIRSTLINE
asm_this_lp
      JSR   ASM_ATEND
      BCS   asm_this_out      ; ran out, leave it on the last line

      LDY   #$01              ; is the next line above the execute pointer
      LDA   (ASM_LPT),Y
      CMP   Bpntrh
      BCC   asm_this_step     ; next line starts below, not this one
      BNE   asm_this_out      ; next line starts above, so this is the one

      DEY
      LDA   (ASM_LPT),Y
      CMP   Bpntrl
      BCS   asm_this_out

asm_this_step
      JSR   ASM_NEXTLINE
      BCS   asm_this_lp

asm_this_out
      RTS

; carry set if ASM_LPT is past the last line. the end of the program is a link
; word whose high byte is zero

ASM_ATEND
      LDY   #$01
      LDA   (ASM_LPT),Y
      BEQ   asm_atend_yes

      CLC
      RTS

asm_atend_yes
      SEC
      RTS

; step ASM_LPT to the next line, carry set if there is one

ASM_NEXTLINE
      JSR   ASM_ATEND
      BCS   asm_next_out

      LDY   #$00
      LDA   (ASM_LPT),Y
      TAX
      INY
      LDA   (ASM_LPT),Y
      STA   ASM_LPT+1
      STX   ASM_LPT
      SEC
asm_next_out
      RTS

; A = the first token of the line at ASM_LPT

ASM_FIRSTTOK
      LDY   #$04
      LDA   (ASM_LPT),Y
      RTS

; ---------------------------------------------------------------------------
; ASM_SETUP   get the working area ready for an assembly
;
; The work buffer and the symbol table both live at the very top of RAM, above
; wherever the code image will end up, so they are in place before pass 1 has
; any idea how big the image will be.
;
;   ASM_OEM  ---> +--------------------+  end of memory as cold start found it
;                 |   work buffer      |  ASM_WRKSZ bytes
;   ASM_WRK  ---> +--------------------+
;                 |   symbol table     |  grows down
;                 +--------------------+
;                 |   code image       |  grows up from the base
;   Ememl    ---> +--------------------+  lowered to protect both
;
; Lowering Ememl is what keeps BASIC out: string space is reset from it in
; LAB_147A and again on every line edit, and garbage collection never looks
; above it either.
; ---------------------------------------------------------------------------

ASM_WRKSZ    = 80             ; expanded line buffer. a typed line cannot
                              ; exceed Ibuffe-Ibuffs, 71 bytes, and the crunch
                              ; is lossless, so 80 has room to spare

ASM_SETUP
      LDA   ASM_FLG           ; has an assembly already taken memory
      BMI   asm_setup_have

      LDA   Ememl             ; no, so what is there now is the true top
      STA   ASM_OEM
      LDA   Ememh
      STA   ASM_OEM+1
      BRA   asm_setup_top

asm_setup_have
      LDA   ASM_OEM           ; yes, so give it all back before taking it
      STA   Ememl             ; again, or reservations would accumulate
      LDA   ASM_OEM+1
      STA   Ememh

asm_setup_top
      STZ   ASM_FLG           ; the old image is gone as of now

; string space has to be empty before the ceiling can move, because strings
; already allocated cannot be picked up and put down somewhere else. after a
; CLEAR, Sstorl is Ememl and nothing is allocated

      LDA   Sstorl
      CMP   Ememl
      BNE   asm_setup_clr

      LDA   Sstorh
      CMP   Ememh
      BEQ   asm_setup_free    ; nothing allocated, variables can be left alone

asm_setup_clr
      LDA   #<asm_msg_clr     ; say so rather than doing it silently
      LDY   #>asm_msg_clr
      JSR   LAB_18C3
      JSR   LAB_147A          ; the body of CLEAR

asm_setup_free
      SEC                     ; work buffer sits just under the top
      LDA   Ememl
      SBC   #ASM_WRKSZ
      STA   ASM_WRK
      LDA   Ememh
      SBC   #$00
      STA   ASM_WRK+1

      LDA   ASM_WRK           ; symbol table starts empty, growing down from
      STA   ASM_SLN           ; the bottom of the work buffer
      LDA   ASM_WRK+1
      STA   ASM_SLN+1
      STZ   ASM_NSY
      RTS

; ---------------------------------------------------------------------------
; ASM_EXPAND   expand the line at ASM_LPT into the work buffer as plain text
;
; This is the whole reason no change to the tokenizer was needed. Assembly
; lines are crunched exactly like BASIC ones - BEQ DONE is stored as BEQ, the
; DO token, NE - and the crunch is lossless because LIST has to be able to put
; the line back. So the same table LIST uses, LAB_KEYT, puts it back here too.
;
; Lower case is folded up on the way through, since the tokenizer only ever
; matches upper case and a mnemonic typed in lower case arrives untouched.
; Text inside quotes is left exactly as it was, because that is how the
; tokenizer stored it and TEXT "Hello" has to keep its capitals.
; ---------------------------------------------------------------------------

ASM_EXPAND
      LDY   #$04              ; first token of the line
      STY   ASM_CNT
      STZ   ASM_BUF
      STZ   ASM_QUO

asm_exp_lp
      LDY   ASM_CNT
      LDA   (ASM_LPT),Y
      INC   ASM_CNT
      CMP   #$00              ; test the byte, not the counter - the INC above
      BEQ   asm_exp_end       ; has already trodden on the flags from the load
                              ; the line's terminating null
      BMI   asm_exp_tok       ; a token, needs the table

      CMP   #$22              ; a quote flips us in or out of a string
      BNE   asm_exp_case

      PHA
      LDA   ASM_QUO
      EOR   #$FF
      STA   ASM_QUO
      PLA
      BRA   asm_exp_put

asm_exp_case
      LDX   ASM_QUO           ; inside a string nothing is touched
      BNE   asm_exp_put

      CMP   #'a'              ; fold a-z up to A-Z
      BCC   asm_exp_put
      CMP   #'z'+1
      BCS   asm_exp_put
      AND   #$DF

asm_exp_put
      JSR   asm_exp_store
      BRA   asm_exp_lp

asm_exp_end
      LDA   #$00
      JSR   asm_exp_store
      RTS

; a token. this is LAB_152E's index arithmetic, writing to the buffer instead
; of to the screen: LAB_KEYT + (token-$80)*4, then a length, the first
; character, and a pointer to the rest of the word

asm_exp_tok
      LDX   #>LAB_KEYT
      ASL                     ; *2, and the carry drops the $80
      ASL                     ; *4
      BCC   asm_exp_t1

      INX
      CLC
asm_exp_t1
      ADC   #<LAB_KEYT
      BCC   asm_exp_t2

      INX
asm_exp_t2
      STA   ASM_TMP
      STX   ASM_TMP+1

      LDY   #$00
      LDA   (ASM_TMP),Y       ; length of the keyword
      TAX
      INY
      LDA   (ASM_TMP),Y       ; its first character
      DEX
      BEQ   asm_exp_t4        ; a one character keyword, that is all of it

      JSR   asm_exp_store

      INY                     ; the rest of the word lives elsewhere
      LDA   (ASM_TMP),Y
      PHA
      INY
      LDA   (ASM_TMP),Y
      STA   ASM_TMP+1
      PLA
      STA   ASM_TMP

      LDY   #$00
asm_exp_t3
      LDA   (ASM_TMP),Y
      DEX
      BEQ   asm_exp_t4

      JSR   asm_exp_store
      INY
      BRA   asm_exp_t3

asm_exp_t4
      JSR   asm_exp_store
      JMP   asm_exp_lp

; put A in the work buffer, unless it is already full

asm_exp_store
      PHY                     ; Y is the caller's place in the keyword table,
      PHA                     ; it must come back untouched
      LDA   ASM_BUF
      CMP   #ASM_WRKSZ-1
      BCS   asm_exp_full

      TAY
      PLA
      STA   (ASM_WRK),Y
      INC   ASM_BUF
      PLY
      RTS

asm_exp_full
      PLA
      PLY
      LDX   #ERRNUM_ASM
      JMP   ASM_ERROR

; ---------------------------------------------------------------------------
; ASM_ERROR   raise error X, naming the BASIC line being assembled
;
; The assembler walks the program itself rather than executing it, so Clinel
; and Clineh do not point at the line that is at fault. Setting them from the
; header first means EhBASIC's own " Error in line nnnn" does the reporting,
; and it comes out right even when ASSEMBLE was typed at the prompt.
; ---------------------------------------------------------------------------

ASM_ERROR
      PHX
      LDY   #$02
      LDA   (ASM_LPT),Y
      STA   Clinel
      INY
      LDA   (ASM_LPT),Y
      STA   Clineh
      PLX
      JMP   LAB_XERR

asm_msg_clr
      .byte $0D,$0A,"*** ASSEMBLED, VARIABLES CLEARED",$0D,$0A,$00

; ---------------------------------------------------------------------------
; location counter, allocation and relocation
; ---------------------------------------------------------------------------

; start of a pass. in relocatable mode the counter is an offset from the image
; base, which is not known until pass 1 has finished, so pass 1 counts from
; zero and pass 2 counts from the base it was given

ASM_RESETPC
      LDA   #$80
      STA   ASM_REL           ; relocatable until an ORG says otherwise
      LDA   ASM_PAS
      CMP   #$02
      BEQ   asm_rpc_2

      STZ   ASM_LC            ; pass 1 measures from zero
      STZ   ASM_LC+1
      RTS

asm_rpc_2
      LDA   ASM_BAS
      STA   ASM_LC
      LDA   ASM_BAS+1
      STA   ASM_LC+1
      RTS

; pass 1 is done, so the image size is known. put the image immediately below
; the symbol table and drop the ceiling to match

ASM_ALLOC
      LDA   ASM_REL           ; with no ORG anywhere, the size is simply what
      BEQ   asm_alloc_sized   ; pass 1 counted up to. with one, ASM_D_ORG has
                              ; already put the size away
      LDA   ASM_LC
      STA   ASM_SIZ
      LDA   ASM_LC+1
      STA   ASM_SIZ+1

asm_alloc_sized
      SEC
      LDA   ASM_SLN           ; base = bottom of the symbol table - size
      SBC   ASM_SIZ
      STA   ASM_BAS
      LDA   ASM_SLN+1
      SBC   ASM_SIZ+1
      STA   ASM_BAS+1

      LDA   ASM_BAS           ; must not have run down into the arrays
      CMP   Earryl
      LDA   ASM_BAS+1
      SBC   Earryh
      BCC   asm_alloc_oom

      LDA   ASM_BAS           ; take the memory
      STA   Ememl
      STA   Sstorl
      LDA   ASM_BAS+1
      STA   Ememh
      STA   Sstorh

      LDA   ASM_SLN           ; remember where the symbols start
      STA   ASM_SYM
      LDA   ASM_SLN+1
      STA   ASM_SYM+1
      RTS

asm_alloc_oom
      LDX   #$0C              ; "Out of memory"
      JMP   ASM_ERROR


; ---------------------------------------------------------------------------
; reading the expanded line
;
; The line stays in the work buffer and is walked with ASM_BUF as the index,
; so a field is described by where it starts and how long it is rather than by
; being copied anywhere.
; ---------------------------------------------------------------------------

; A = the character at ASM_BUF, without stepping past it

ASM_PEEK
      LDY   ASM_BUF
      LDA   (ASM_WRK),Y
      RTS

; as above, then step past it

ASM_NEXT
      JSR   ASM_PEEK
      INC   ASM_BUF
      RTS

; skip spaces. carry set if what follows ends the line - the null, or the ";"
; that starts a comment

ASM_SKIPSP
      JSR   ASM_PEEK
      CMP   #' '
      BNE   asm_sksp_t

      INC   ASM_BUF
      BRA   ASM_SKIPSP

asm_sksp_t
      CMP   #$00
      BEQ   asm_sksp_end

      CMP   #';'
      BEQ   asm_sksp_end

      CLC
      RTS

asm_sksp_end
      SEC
      RTS

; collect the identifier at ASM_BUF into ASM_FS/ASM_FL. letters, digits and
; underscore. carry clear if there was one

ASM_FIELD
      LDA   ASM_BUF
      STA   ASM_FS
      STZ   ASM_FL
asm_fld_lp
      JSR   ASM_PEEK
      JSR   ASM_ISIDENT
      BCC   asm_fld_end

      INC   ASM_BUF
      INC   ASM_FL
      BRA   asm_fld_lp

asm_fld_end
      LDA   ASM_FL
      BEQ   asm_fld_none

      CLC
      RTS

asm_fld_none
      SEC
      RTS

; carry set if A is a letter, a digit or "_"

ASM_ISIDENT
      CMP   #'_'
      BEQ   asm_ident_yes

      CMP   #'0'
      BCC   asm_ident_no

      CMP   #'9'+1
      BCC   asm_ident_yes

      CMP   #'A'
      BCC   asm_ident_no

      CMP   #'Z'+1
      BCS   asm_ident_no

asm_ident_yes
      SEC
      RTS

asm_ident_no
      CLC
      RTS

; ---------------------------------------------------------------------------
; ASM_LINE   assemble the one expanded line now in the work buffer
;
; The grammar is
;
;     [|] [label] [mnemonic | directive [operand]] [; comment]
;
; where the leading "|" is optional and exists only to protect indentation,
; see ASM_INDENT above.
;
; with no way to tell a label from a mnemonic by position, because EhBASIC
; throws away the spaces between a line number and the first character (see
; LAB_GFPN) so nothing can be keyed off indentation. The rule is therefore
; that the first field is a label unless it is a mnemonic or a directive.
; ---------------------------------------------------------------------------

ASM_LINE
      STZ   ASM_BUF
      STZ   ASM_OPC
      JSR   ASM_SKIPSP
      BCS   asm_line_done     ; blank line, or only a comment

      CMP   #ASM_INDENT       ; step over the indent prefix if there is one.
      BNE   asm_line_pfx      ; a label can follow it as happily as an
                              ; instruction can, so "|LOOP LDA X" lines a
                              ; label up on the same margin as the code
      INC   ASM_BUF
      JSR   ASM_SKIPSP
      BCS   asm_line_done     ; nothing after it but spaces or a comment

asm_line_pfx
      CMP   #'*'              ; "*=" is ORG written the other way
      BNE   asm_line_field

      INC   ASM_BUF
      JSR   ASM_SKIPSP
      CMP   #'='
      BNE   asm_line_syn

      INC   ASM_BUF
      JMP   ASM_D_ORG

asm_line_field
      JSR   ASM_FIELD
      BCS   asm_line_syn

      JSR   ASM_KEYWORD       ; is that first field an opcode or a directive
      BCS   asm_line_op       ; yes, so the line carries no label

; it was a label. define it here, step over an optional ":", and then look for
; a mnemonic or directive after it

      JSR   ASM_DEFLABEL
      JSR   ASM_PEEK
      CMP   #':'
      BNE   asm_line_l2

      INC   ASM_BUF
asm_line_l2
      JSR   ASM_SKIPSP
      BCS   asm_line_done     ; a label on its own is a whole line

      JSR   ASM_FIELD
      BCS   asm_line_syn

      JSR   ASM_KEYWORD
      BCC   asm_line_syn      ; not an opcode or a directive, so nonsense

asm_line_op
      LDA   ASM_LC            ; where this line's bytes will start
      STA   ASM_LC0
      LDA   ASM_LC+1
      STA   ASM_LC0+1
      JSR   asm_line_call
      JMP   ASM_LISTLINE

asm_line_call
      JMP   (ASM_DISPATCH,X)  ; X came back as the handler index

asm_line_syn
      LDX   #ERRNUM_ASM
      JMP   ASM_ERROR

asm_line_done
      RTS

; ---------------------------------------------------------------------------
; ASM_KEYWORD   is the field in ASM_FS/ASM_FL a directive or a mnemonic
;
; carry set and X = the dispatch index if so. Directives are checked first,
; and none of them collides with a mnemonic.
; ---------------------------------------------------------------------------

ASM_DISPATCH
      .word ASM_D_BYTE        ; 0
      .word ASM_D_WORD        ; 2
      .word ASM_D_TEXT        ; 4
      .word ASM_D_EQU         ; 6
      .word ASM_D_DS          ; 8
      .word ASM_D_ORG         ; 10
      .word ASM_OPCODE        ; 12, the field matched a mnemonic

; length, letters, dispatch index. a zero length ends the table

ASM_DIRTAB
      .byte 4,"BYTE",0
      .byte 4,"WORD",2
      .byte 4,"TEXT",4
      .byte 3,"EQU",6
      .byte 2,"DS",8
      .byte 3,"ORG",10
      .byte 0

ASM_KEYWORD
      LDA   #<ASM_DIRTAB
      STA   ASM_TMP
      LDA   #>ASM_DIRTAB
      STA   ASM_TMP+1

asm_kw_lp
      LDY   #$00
      LDA   (ASM_TMP),Y       ; length of this entry
      BEQ   asm_kw_mnem       ; end of the table, try the mnemonics

      CMP   ASM_FL            ; the field has to be the same length
      BNE   asm_kw_skip

      STA   ASM_CNT           ; letters left to compare
      LDA   #$01
      STA   ASM_T2            ; offset into the table entry
      LDA   ASM_FS
      STA   ASM_T3            ; offset into the line buffer

asm_kw_cmp
      LDY   ASM_T2
      LDA   (ASM_TMP),Y
      LDY   ASM_T3
      CMP   (ASM_WRK),Y
      BNE   asm_kw_skip

      INC   ASM_T2
      INC   ASM_T3
      DEC   ASM_CNT
      BNE   asm_kw_cmp

      LDY   ASM_T2            ; matched, the index sits after the letters
      LDA   (ASM_TMP),Y
      TAX
      SEC
      RTS

asm_kw_skip
      LDY   #$00              ; step over length, letters and index
      LDA   (ASM_TMP),Y
      SEC
      ADC   #$01              ; carry is set, so this adds two
      CLC
      ADC   ASM_TMP
      STA   ASM_TMP
      BCC   asm_kw_lp

      INC   ASM_TMP+1
      BRA   asm_kw_lp

asm_kw_mnem
      JSR   ASM_MNEMONIC
      BCC   asm_kw_no

      LDX   #12
      SEC
      RTS

asm_kw_no
      CLC
      RTS

; ---------------------------------------------------------------------------
; ASM_MNEMONIC   does the field name an instruction
;
; Three letters, packed the same way OPNAME holds them, then a search of that
; table. RMB, SMB, BBR and BBS take a fourth character, a bit number, which is
; kept in ASM_BIT and folded into the opcode later.
; ---------------------------------------------------------------------------

ASM_MNEMONIC
      STZ   ASM_BIT
      LDA   ASM_FL
      CMP   #$03
      BEQ   asm_mn_pack

      CMP   #$04              ; four characters is only legal for the bit ones
      BNE   asm_mn_no

      LDY   ASM_FS            ; the fourth has to be a digit 0 to 7
      INY
      INY
      INY
      LDA   (ASM_WRK),Y
      SEC
      SBC   #'0'
      CMP   #$08
      BCS   asm_mn_no

      STA   ASM_BIT

asm_mn_pack
      STZ   ASM_MNE           ; pack three letters, five bits each, into the
      STZ   ASM_MNE+1         ; top fifteen bits of ASM_MNE
      LDY   ASM_FS
      LDX   #$03
asm_mn_pk
      LDA   (ASM_WRK),Y
      SEC
      SBC   #$40              ; "A" is 1
      CMP   #$1B
      BCS   asm_mn_no         ; not a letter at all

      PHY
      LDY   #$05
asm_mn_sh
      ASL   ASM_MNE
      ROL   ASM_MNE+1
      DEY
      BNE   asm_mn_sh

      ORA   ASM_MNE           ; drop the five bits in at the bottom
      STA   ASM_MNE
      PLY
      INY
      DEX
      BNE   asm_mn_pk

      ASL   ASM_MNE           ; left align, OPNAME is stored that way
      ROL   ASM_MNE+1

; now find it. the table is short, a straight walk is cheaper than anything
; cleverer would be

      LDX   #$01              ; MN_ILL at 0 is not a real mnemonic
asm_mn_find
      TXA
      ASL
      TAY
      LDA   OPNAME,Y
      CMP   ASM_MNE
      BNE   asm_mn_step

      LDA   OPNAME+1,Y
      CMP   ASM_MNE+1
      BNE   asm_mn_step

      STX   ASM_MNI           ; found it
      LDA   ASM_BIT           ; a bit number is only legal on the four that
      BEQ   asm_mn_yes        ; take one, and those four have to have had it

      CPX   #MN_SMB+1
      BCS   asm_mn_no

asm_mn_yes
      LDA   ASM_FL            ; conversely, those four must be given one
      CMP   #$04
      BEQ   asm_mn_ok

      CPX   #MN_SMB+1
      BCC   asm_mn_no

asm_mn_ok
      SEC
      RTS

asm_mn_step
      INX
      CPX   #MN_COUNT
      BCC   asm_mn_find

asm_mn_no
      CLC
      RTS

; ---------------------------------------------------------------------------
; symbol table
;
; Twelve bytes an entry, so a walk is a straight add with no multiply:
;
;   +0   eight characters of name, space padded. longer names are significant
;        to eight characters only
;   +8   value, low/high
;   +10  flags, bit 7 set while the value is still an offset from the image
;        base rather than a real address
;   +11  spare
;
; The table grows down from ASM_WRK, so it is already where it will finally
; live before pass 1 has any idea how big the image is.
; ---------------------------------------------------------------------------

ASM_SYMSZ    = 12
ASM_NAMSZ    = 8

; ASM_DEFLABEL   define the field in ASM_FS/ASM_FL at the current location
;
; Pass 1 does the defining. Pass 2 only checks the value still agrees, which
; catches a phase error rather than silently emitting the wrong thing.

ASM_DEFLABEL
      LDA   ASM_LC
      STA   ASM_VAL
      LDA   ASM_LC+1
      STA   ASM_VAL+1
      LDA   ASM_REL           ; relocatable if we have not passed an ORG
      STA   ASM_T2

; fall through into ASM_DEFSYM

; ASM_DEFSYM   define ASM_FS/ASM_FL as ASM_VAL, flags in ASM_T2

ASM_DEFSYM
      LDA   ASM_PAS
      CMP   #$02
      BEQ   asm_defs_out      ; pass 2 leaves the table alone

      JSR   ASM_LOOKUP
      BCC   asm_defs_new

      LDX   #ERRNUM_DL        ; already there
      JMP   ASM_ERROR

asm_defs_new
      SEC                     ; make room for one more entry
      LDA   ASM_SLN
      SBC   #ASM_SYMSZ
      STA   ASM_SLN
      STA   ASM_SPT
      LDA   ASM_SLN+1
      SBC   #$00
      STA   ASM_SLN+1
      STA   ASM_SPT+1

      LDA   ASM_SLN           ; do not run down into the arrays
      CMP   Earryl
      LDA   ASM_SLN+1
      SBC   Earryh
      BCS   asm_defs_room

      LDX   #$0C              ; "Out of memory"
      JMP   ASM_ERROR

asm_defs_room
      JSR   ASM_PUTNAME
      LDY   #$08
      LDA   ASM_VAL
      STA   (ASM_SPT),Y
      INY
      LDA   ASM_VAL+1
      STA   (ASM_SPT),Y
      INY
      LDA   ASM_T2
      STA   (ASM_SPT),Y
      INC   ASM_NSY
asm_defs_out
      RTS

; copy the field into the entry at ASM_SPT, padded with spaces and truncated
; to eight characters

ASM_PUTNAME
      LDY   #$00
asm_pn_lp
      CPY   ASM_FL
      BCS   asm_pn_pad

      CPY   #ASM_NAMSZ
      BCS   asm_pn_done

      PHY
      TYA
      CLC
      ADC   ASM_FS
      TAY
      LDA   (ASM_WRK),Y
      PLY
      STA   (ASM_SPT),Y
      INY
      BRA   asm_pn_lp

asm_pn_pad
      CPY   #ASM_NAMSZ
      BCS   asm_pn_done

      LDA   #' '
      STA   (ASM_SPT),Y
      INY
      BRA   asm_pn_pad

asm_pn_done
      RTS

; ASM_LOOKUP   find the field in ASM_FS/ASM_FL
;
; carry set and ASM_SPT pointing at the entry if it is there

ASM_LOOKUP
      LDA   ASM_WRK           ; walk down from the top of the table
      STA   ASM_SPT
      LDA   ASM_WRK+1
      STA   ASM_SPT+1
      LDA   ASM_NSY
      BEQ   asm_lk_no

      STA   ASM_CNT
asm_lk_lp
      SEC
      LDA   ASM_SPT
      SBC   #ASM_SYMSZ
      STA   ASM_SPT
      LDA   ASM_SPT+1
      SBC   #$00
      STA   ASM_SPT+1

      JSR   ASM_CMPNAME
      BCS   asm_lk_yes

      DEC   ASM_CNT
      BNE   asm_lk_lp

asm_lk_no
      CLC
      RTS

asm_lk_yes
      SEC
      RTS

; compare the field with the name at ASM_SPT, carry set if they match

ASM_CMPNAME
      LDY   #$00
asm_cn_lp
      CPY   ASM_FL
      BCS   asm_cn_pad

      CPY   #ASM_NAMSZ
      BCS   asm_cn_yes        ; both truncate to the same eight characters

      PHY
      TYA
      CLC
      ADC   ASM_FS
      TAY
      LDA   (ASM_WRK),Y
      PLY
      CMP   (ASM_SPT),Y
      BNE   asm_cn_no

      INY
      BRA   asm_cn_lp

asm_cn_pad
      CPY   #ASM_NAMSZ
      BCS   asm_cn_yes

      LDA   (ASM_SPT),Y
      CMP   #' '
      BNE   asm_cn_no

      INY
      BRA   asm_cn_pad

asm_cn_yes
      SEC
      RTS

asm_cn_no
      CLC
      RTS

; ASM_RELOC   turn every offset in the table into a real address
;
; Pass 1 recorded relocatable symbols as offsets from the start of the image,
; because where the image would sit was not known until the size was. Now it
; is, so add the base in and clear the flag.

ASM_RELOC
      LDA   ASM_NSY
      BEQ   asm_rl_out

      STA   ASM_CNT
      LDA   ASM_WRK
      STA   ASM_SPT
      LDA   ASM_WRK+1
      STA   ASM_SPT+1

asm_rl_lp
      SEC
      LDA   ASM_SPT
      SBC   #ASM_SYMSZ
      STA   ASM_SPT
      LDA   ASM_SPT+1
      SBC   #$00
      STA   ASM_SPT+1

      LDY   #$0A
      LDA   (ASM_SPT),Y
      BPL   asm_rl_next       ; absolute already, leave it alone

      LDA   #$00              ; clear the flag
      STA   (ASM_SPT),Y

      LDY   #$08
      CLC
      LDA   (ASM_SPT),Y
      ADC   ASM_BAS
      STA   (ASM_SPT),Y
      INY
      LDA   (ASM_SPT),Y
      ADC   ASM_BAS+1
      STA   (ASM_SPT),Y

asm_rl_next
      DEC   ASM_CNT
      BNE   asm_rl_lp

asm_rl_out
      RTS

; ---------------------------------------------------------------------------
; operand values
;
; Literals, labels, "*" for the current location, an optional "<" or ">" byte
; selector and one optional "+n" or "-n". Left to right, no precedence - this
; is not the BASIC evaluator and does not pretend to be.
;
; ASM_T3 comes back non zero if the value was written in a form that is only
; ever eight bits wide, which is what decides zero page against absolute.
; ---------------------------------------------------------------------------

ASM_EXPR
      STZ   ASM_T3            ; assume sixteen bit until told otherwise
      STZ   ASM_T2            ; 0 none, 1 low byte wanted, 2 high byte
      JSR   ASM_SKIPSP
      BCC   asm_ex_sel0

      JMP   asm_ex_syn

asm_ex_sel0

      CMP   #'<'
      BNE   asm_ex_hi

      INC   ASM_BUF
      LDA   #$01
      STA   ASM_T2
      BRA   asm_ex_term

asm_ex_hi
      CMP   #'>'
      BNE   asm_ex_term

      INC   ASM_BUF
      LDA   #$02
      STA   ASM_T2

asm_ex_term
      JSR   ASM_TERM
      JSR   ASM_PEEK          ; one optional offset
      CMP   #'+'
      BEQ   asm_ex_plus

      CMP   #'-'
      BEQ   asm_ex_minus

      BRA   asm_ex_sel

; the offset's own width must not count towards the operand's, or LABEL+2
; would narrow to zero page on the strength of the 2. so ASM_T3 is put back
; the way it was after the second term is read

asm_ex_plus
      INC   ASM_BUF
      JSR   asm_ex_save
      CLC
      PLA
      ADC   ASM_VAL
      STA   ASM_VAL
      PLA
      ADC   ASM_VAL+1
      STA   ASM_VAL+1
      BRA   asm_ex_sel

asm_ex_minus
      INC   ASM_BUF
      JSR   asm_ex_save
      SEC
      PLA
      SBC   ASM_VAL
      STA   ASM_VAL
      PLA
      SBC   ASM_VAL+1
      STA   ASM_VAL+1
      BRA   asm_ex_sel

; stack the value and the width, read the next term, restore the width and
; leave the old value on the stack for the caller to add or subtract

asm_ex_save
      PLA                     ; our own return address, out of the way
      TAX
      PLA
      TAY
      LDA   ASM_VAL+1
      PHA
      LDA   ASM_VAL
      PHA
      LDA   ASM_T3
      PHA
      PHY                     ; put the return address back
      PHX
      JSR   ASM_TERM
      PLA                     ; lift the return address again
      TAX
      PLA
      TAY
      PLA
      STA   ASM_T3
      PHY
      PHX
      RTS

asm_ex_sel
      LDA   ASM_T2            ; apply a byte selector if there was one
      BEQ   asm_ex_out

      CMP   #$01
      BNE   asm_ex_high

      STZ   ASM_VAL+1         ; "<" keeps the low byte, and forces zero page
      LDA   #$01
      STA   ASM_T3
      RTS

asm_ex_high
      LDA   ASM_VAL+1         ; ">" keeps the high byte, also eight bits
      STA   ASM_VAL
      STZ   ASM_VAL+1
      LDA   #$01
      STA   ASM_T3

asm_ex_out
      RTS

asm_ex_syn
      LDX   #ERRNUM_ASM
      JMP   ASM_ERROR

; ASM_TERM   one literal, label or "*"

ASM_TERM
      JSR   ASM_PEEK
      CMP   #'$'
      BNE   asm_tm_1

      JMP   ASM_HEX

asm_tm_1
      CMP   #'%'
      BNE   asm_tm_2

      JMP   ASM_BIN

asm_tm_2
      CMP   #$27              ; a single quoted character
      BNE   asm_tm_3

      JMP   ASM_CHR

asm_tm_3
      CMP   #'*'
      BNE   asm_tm_4

      JMP   ASM_HERE

asm_tm_4
      CMP   #'0'
      BCC   asm_tm_label

      CMP   #'9'+1
      BCS   asm_tm_label

      JMP   ASM_DEC

; a syntax error is too far from the value parsers below to branch to, so they
; go through here

asm_v_syn
      JMP   asm_ex_syn

asm_tm_label
      JSR   ASM_FIELD
      BCS   asm_v_syn

      JSR   ASM_LOOKUP
      BCS   asm_tm_got

; not defined yet. that is normal in pass 1, where a forward reference has
; simply not been reached, and an error in pass 2

      LDA   ASM_PAS
      CMP   #$02
      BEQ   asm_tm_undef

      STZ   ASM_VAL           ; a placeholder value. the width does not come
      STZ   ASM_VAL+1         ; from it, so nothing later depends on it
      RTS

asm_tm_undef
      LDX   #ERRNUM_UL
      JMP   ASM_ERROR

asm_tm_got
      LDY   #$08
      LDA   (ASM_SPT),Y
      STA   ASM_VAL
      INY
      LDA   (ASM_SPT),Y
      STA   ASM_VAL+1
      RTS

; "*" is where we are now

ASM_HERE
      INC   ASM_BUF
      LDA   ASM_LC
      STA   ASM_VAL
      LDA   ASM_LC+1
      STA   ASM_VAL+1
      RTS

; a character literal, 'x'. the closing quote is optional

ASM_CHR
      INC   ASM_BUF
      JSR   ASM_NEXT
      STA   ASM_VAL
      STZ   ASM_VAL+1
      LDA   #$01
      STA   ASM_T3            ; always eight bits
      JSR   ASM_PEEK
      CMP   #$27
      BNE   asm_chr_out

      INC   ASM_BUF
asm_chr_out
      RTS

; $hex. one or two digits is an eight bit value, three or four a sixteen bit
; one, and that is what decides zero page against absolute

ASM_HEX
      INC   ASM_BUF
      STZ   ASM_VAL
      STZ   ASM_VAL+1
      STZ   ASM_CNT
asm_hx_lp
      JSR   ASM_PEEK
      JSR   ASM_HEXDIG
      BCC   asm_hx_end

      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ORA   ASM_VAL
      STA   ASM_VAL
      INC   ASM_BUF
      INC   ASM_CNT
      BRA   asm_hx_lp

asm_hx_end
      LDA   ASM_CNT
      BEQ   asm_v_syn         ; "$" with no digits after it

      CMP   #$03
      BCS   asm_hx_out        ; three or four digits, sixteen bit

      LDA   #$01
      STA   ASM_T3
asm_hx_out
      RTS

; A holds a character. carry set and A = its value if it is a hex digit

ASM_HEXDIG
      CMP   #'0'
      BCC   asm_hd_no

      CMP   #'9'+1
      BCS   asm_hd_af

      SEC
      SBC   #'0'
      SEC
      RTS

asm_hd_af
      CMP   #'A'
      BCC   asm_hd_no

      CMP   #'G'
      BCS   asm_hd_no

      SEC
      SBC   #'A'-10
      SEC
      RTS

asm_hd_no
      CLC
      RTS

; %binary. eight digits or fewer is an eight bit value

ASM_BIN
      INC   ASM_BUF
      STZ   ASM_VAL
      STZ   ASM_VAL+1
      STZ   ASM_CNT
asm_bn_lp
      JSR   ASM_PEEK
      CMP   #'0'
      BCC   asm_bn_end

      CMP   #'2'
      BCS   asm_bn_end

      SEC
      SBC   #'0'
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ORA   ASM_VAL
      STA   ASM_VAL
      INC   ASM_BUF
      INC   ASM_CNT
      BRA   asm_bn_lp

asm_bn_end
      LDA   ASM_CNT
      BEQ   asm_v_syn2

      CMP   #$09
      BCS   asm_bn_out

      LDA   #$01
      STA   ASM_T3
asm_bn_out
      RTS

; another reach to the syntax error, this end of the value parsers

asm_v_syn2
      JMP   asm_ex_syn

; plain decimal. under 256 is an eight bit value

ASM_DEC
      STZ   ASM_VAL
      STZ   ASM_VAL+1
asm_dc_lp
      JSR   ASM_PEEK
      CMP   #'0'
      BCC   asm_dc_end

      CMP   #'9'+1
      BCS   asm_dc_end

      SEC
      SBC   #'0'
      PHA
      JSR   ASM_TIMES10
      PLA
      CLC
      ADC   ASM_VAL
      STA   ASM_VAL
      BCC   asm_dc_nc

      INC   ASM_VAL+1
asm_dc_nc
      INC   ASM_BUF
      BRA   asm_dc_lp

asm_dc_end
      LDA   ASM_VAL+1
      BNE   asm_dc_out

      LDA   #$01
      STA   ASM_T3
asm_dc_out
      RTS

; ASM_VAL = ASM_VAL * 10, done as (v*4 + v) * 2

ASM_TIMES10
      LDA   ASM_VAL+1         ; through the stack rather than scratch bytes,
      PHA                     ; ASM_T2 and ASM_T3 are both live here
      LDA   ASM_VAL
      PHA
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      CLC
      PLA
      ADC   ASM_VAL
      STA   ASM_VAL
      PLA
      ADC   ASM_VAL+1
      STA   ASM_VAL+1
      ASL   ASM_VAL
      ROL   ASM_VAL+1
      RTS

; ---------------------------------------------------------------------------
; emitting
; ---------------------------------------------------------------------------

; put A at the location counter, in pass 2 only, and step the counter on

ASM_PUT
      PHA
      LDA   ASM_PAS
      CMP   #$02
      BNE   asm_put_skip

      PLA
      PHA
      LDY   #$00
      STA   (ASM_LC),Y
asm_put_skip
      PLA
      INC   ASM_LC
      BNE   asm_put_out

      INC   ASM_LC+1
asm_put_out
      RTS

; ---------------------------------------------------------------------------
; ASM_OPCODE   assemble an instruction
;
; The syntactic shape of the operand picks the mode; where two modes share a
; shape the first is tried and the second used if the opcode search comes back
; empty. That keeps every mnemonic special case out of the parser - only
; BBR/BBS, which are the only instructions with two operands, need naming.
; ---------------------------------------------------------------------------

ASM_OPCODE
      JSR   ASM_SKIPSP
      BCS   asm_op_none       ; nothing after the mnemonic

      CMP   #'#'
      BEQ   asm_op_imm

      CMP   #'('
      BEQ   asm_op_ind

      CMP   #'A'              ; a lone "A" is the accumulator
      BNE   asm_op_addr_j

      LDY   ASM_BUF
      INY
      LDA   (ASM_WRK),Y
      JSR   ASM_ISIDENT
      BCS   asm_op_addr_j     ; "A" was the start of a longer name

      INC   ASM_BUF
      BRA   asm_op_none

asm_op_addr_j
      JMP   asm_op_addr

; no operand at all. accumulator first, then implied - the six instructions
; with an accumulator form have no implied form and the other way round

asm_op_none
      LDA   ASM_MNI
      CMP   #MN_SMB+1
      BCC   asm_op_bitmiss    ; RMB and friends must be given an operand

      LDA   #MD_ACC
      JSR   ASM_TRY
      BCS   asm_op_emit0

      LDA   #MD_IMP
      JSR   ASM_TRY
      BCS   asm_op_emit0

      JMP   asm_op_bad

asm_op_bitmiss
      JMP   asm_op_bad

asm_op_emit0
      JMP   ASM_EMIT0

; "#nn"

asm_op_imm
      INC   ASM_BUF
      JSR   ASM_EXPR
      LDA   #MD_IMM
      JSR   ASM_TRY
      BCC   asm_op_bad

      JMP   ASM_EMIT1

; something in brackets

asm_op_ind
      INC   ASM_BUF
      JSR   ASM_EXPR
      JSR   ASM_SKIPSP
      CMP   #','
      BEQ   asm_op_indx

      CMP   #')'
      BNE   asm_op_bad

      INC   ASM_BUF
      JSR   ASM_SKIPSP        ; "(nn),Y" or plain "(nn)"
      BCS   asm_op_izp

      CMP   #','
      BNE   asm_op_izp

      INC   ASM_BUF
      JSR   ASM_SKIPSP
      CMP   #'Y'
      BNE   asm_op_bad

      INC   ASM_BUF
      LDA   #MD_IZY
      JSR   ASM_TRY
      BCC   asm_op_bad

      JMP   ASM_EMIT1

asm_op_izp
      LDA   #MD_IZP           ; the 65C02 (zp) form
      JSR   ASM_TRY
      BCC   asm_op_ind16

      JMP   ASM_EMIT1

asm_op_ind16
      LDA   #MD_IND           ; only JMP has this
      JSR   ASM_TRY
      BCC   asm_op_bad

      JMP   ASM_EMIT2

; "(nn,X)" or "(nnnn,X)"

asm_op_indx
      INC   ASM_BUF
      JSR   ASM_SKIPSP
      CMP   #'X'
      BNE   asm_op_bad

      INC   ASM_BUF
      JSR   ASM_SKIPSP
      CMP   #')'
      BNE   asm_op_bad

      INC   ASM_BUF
      LDA   #MD_IZX
      JSR   ASM_TRY
      BCC   asm_op_aix

      JMP   ASM_EMIT1

asm_op_aix
      LDA   #MD_AIX           ; only JMP has this one either
      JSR   ASM_TRY
      BCC   asm_op_bad

      JMP   ASM_EMIT2

asm_op_bad
      LDX   #ERRNUM_ASM
      JMP   ASM_ERROR

; a bare address. branches take one, the bit test instructions take two, and
; everything else narrows between zero page and absolute on how the operand
; was written rather than on what it turns out to be worth - see ASM_EXPR

asm_op_addr
      LDA   ASM_MNI
      CMP   #MN_SMB+1
      BCS   asm_op_a1

      CMP   #MN_RMB           ; RMB and SMB are plain zero page
      BCS   asm_op_a1

      JSR   ASM_EXPR          ; BBR and BBS, "nn,target"
      JSR   ASM_SKIPSP
      CMP   #','
      BNE   asm_op_bad

      LDA   ASM_VAL           ; keep the zero page byte
      PHA
      INC   ASM_BUF
      JSR   ASM_EXPR
      LDA   #MD_ZPR
      JSR   ASM_TRY
      BCC   asm_op_bad2

      PLA
      JMP   ASM_EMITZPR

asm_op_bad2
      PLA
      BRA   asm_op_bad

asm_op_a1
      LDA   #MD_REL           ; a branch, if this mnemonic has one
      STA   ASM_TMP
      LDA   #MD_REL
      JSR   ASM_TRY
      BCC   asm_op_a2

      JSR   ASM_EXPR
      JMP   ASM_EMITREL

asm_op_a2
      JSR   ASM_EXPR
      JSR   ASM_SKIPSP
      BCS   asm_op_a_plain

      CMP   #','
      BNE   asm_op_a_plain

      INC   ASM_BUF
      JSR   ASM_SKIPSP
      CMP   #'X'
      BEQ   asm_op_ax

      CMP   #'Y'
      BNE   asm_op_bad

      INC   ASM_BUF
      LDA   #MD_ZPY
      LDX   #MD_ABY
      BRA   asm_op_narrow

asm_op_ax
      INC   ASM_BUF
      LDA   #MD_ZPX
      LDX   #MD_ABX
      BRA   asm_op_narrow

asm_op_a_plain
      LDA   #MD_ZP
      LDX   #MD_ABS

; A holds the zero page mode, X the absolute one. ASM_T3 says whether the
; operand was written in a form that is only ever eight bits wide

asm_op_narrow
      STX   ASM_TMP
      LDX   ASM_T3
      BEQ   asm_op_wide

      JSR   ASM_TRY           ; eight bit form, so try zero page first
      BCC   asm_op_wide

      JMP   ASM_EMIT1

asm_op_wide
      LDA   ASM_TMP
      JSR   ASM_TRY
      BCS   asm_op_e2

      JMP   asm_op_bad

asm_op_e2
      JMP   ASM_EMIT2

; ASM_TRY   is there an opcode for ASM_MNI in mode A
;
; carry set and the opcode in ASM_OPC if so. The bit numbered instructions
; carry their bit in the opcode, so it is folded in here.

ASM_TRY
      JSR   ASM_FINDOP
      BCC   asm_try_no

      STX   ASM_OPC
      LDA   ASM_MNI
      CMP   #MN_SMB+1
      BCS   asm_try_yes

      LDA   ASM_BIT           ; bit number goes in bits 4 to 6
      ASL
      ASL
      ASL
      ASL
      ORA   ASM_OPC
      STA   ASM_OPC

asm_try_yes
      SEC
      RTS

asm_try_no
      CLC
      RTS

; ---------------------------------------------------------------------------
; emitting instructions
; ---------------------------------------------------------------------------

ASM_EMIT0
      LDA   ASM_OPC
      JMP   ASM_PUT

ASM_EMIT1
      LDA   ASM_OPC
      JSR   ASM_PUT
      LDA   ASM_VAL+1         ; an eight bit slot has to hold an eight bit value
      BEQ   asm_e1_ok

      LDX   #$08              ; "Function call", the range error EhBASIC uses
      JMP   ASM_ERROR

asm_e1_ok
      LDA   ASM_VAL
      JMP   ASM_PUT

ASM_EMIT2
      LDA   ASM_OPC
      JSR   ASM_PUT
      LDA   ASM_VAL
      JSR   ASM_PUT
      LDA   ASM_VAL+1
      JMP   ASM_PUT

; a branch. the displacement is measured from the byte after the instruction,
; and only pass 2 can check it - pass 1 does not know where anything is yet

ASM_EMITREL
      LDA   ASM_OPC
      JSR   ASM_PUT
      LDA   ASM_PAS
      CMP   #$02
      BNE   asm_rel_skip

      JSR   ASM_DISP
      JMP   ASM_PUT

asm_rel_skip
      LDA   #$00
      JMP   ASM_PUT

; BBR/BBS, opcode then the zero page byte then the displacement. A holds the
; zero page byte on entry

ASM_EMITZPR
      PHA
      LDA   ASM_OPC
      JSR   ASM_PUT
      PLA
      JSR   ASM_PUT
      LDA   ASM_PAS
      CMP   #$02
      BNE   asm_zpr_skip

      JSR   ASM_DISP
      JMP   ASM_PUT

asm_zpr_skip
      LDA   #$00
      JMP   ASM_PUT

; A = the branch displacement from the location counter, which is sitting on
; the displacement byte itself, so the target is measured from LC+1

ASM_DISP
      SEC
      LDA   ASM_VAL
      SBC   ASM_LC
      TAX
      LDA   ASM_VAL+1
      SBC   ASM_LC+1
      TAY                     ; YX = target - here
      TXA
      SEC
      SBC   #$01              ; and one more for the displacement byte
      TAX
      TYA
      SBC   #$00
      TAY

      TXA                     ; must be -128 to +127
      BMI   asm_disp_neg

      CPY   #$00
      BNE   asm_disp_far

      CMP   #$80
      BCS   asm_disp_far

      RTS

asm_disp_neg
      CPY   #$FF
      BNE   asm_disp_far

      CMP   #$80
      BCC   asm_disp_far

      RTS

asm_disp_far
      LDX   #ERRNUM_BR
      JMP   ASM_ERROR

; ---------------------------------------------------------------------------
; directives
; ---------------------------------------------------------------------------

; BYTE n[,n..]

ASM_D_BYTE
      JSR   ASM_EXPR
      LDA   ASM_VAL
      JSR   ASM_PUT
      JSR   ASM_SKIPSP
      BCS   asm_db_out

      CMP   #','
      BNE   asm_db_out

      INC   ASM_BUF
      BRA   ASM_D_BYTE

asm_db_out
      RTS

; WORD n[,n..]

ASM_D_WORD
      JSR   ASM_EXPR
      LDA   ASM_VAL
      JSR   ASM_PUT
      LDA   ASM_VAL+1
      JSR   ASM_PUT
      JSR   ASM_SKIPSP
      BCS   asm_dw_out

      CMP   #','
      BNE   asm_dw_out

      INC   ASM_BUF
      BRA   ASM_D_WORD

asm_dw_out
      RTS

; TEXT "..."   the characters between the quotes, exactly as typed

ASM_D_TEXT
      JSR   ASM_SKIPSP
      CMP   #$22
      BNE   asm_dt_bad

      INC   ASM_BUF
asm_dt_lp
      JSR   ASM_NEXT
      CMP   #$00
      BEQ   asm_dt_bad        ; ran off the end with no closing quote

      CMP   #$22
      BEQ   asm_dt_out

      JSR   ASM_PUT
      BRA   asm_dt_lp

asm_dt_out
      RTS

asm_dt_bad
      LDX   #ERRNUM_ASM
      JMP   ASM_ERROR

; name EQU value. the label has already been defined at the location counter
; by the time we get here, which is not what EQU means, so the value is
; overwritten rather than a second symbol being made

ASM_D_EQU
      JSR   ASM_EXPR
      LDA   ASM_PAS
      CMP   #$02
      BEQ   asm_eq_out

      JSR   ASM_LASTSYM       ; the label just defined on this line
      LDY   #$08
      LDA   ASM_VAL
      STA   (ASM_SPT),Y
      INY
      LDA   ASM_VAL+1
      STA   (ASM_SPT),Y
      INY
      LDA   #$00              ; an EQU value is absolute, never an offset
      STA   (ASM_SPT),Y

asm_eq_out
      RTS

; ASM_SPT = the entry defined most recently

ASM_LASTSYM
      LDA   ASM_SLN
      STA   ASM_SPT
      LDA   ASM_SLN+1
      STA   ASM_SPT+1
      RTS

; DS n   reserve n bytes without emitting anything

ASM_D_DS
      JSR   ASM_EXPR
      LDA   ASM_VAL
      BNE   asm_ds_go

      LDA   ASM_VAL+1
      BEQ   asm_ds_out

asm_ds_go
      CLC
      LDA   ASM_LC
      ADC   ASM_VAL
      STA   ASM_LC
      LDA   ASM_LC+1
      ADC   ASM_VAL+1
      STA   ASM_LC+1

asm_ds_out
      RTS

; ORG addr, or "*=addr"
;
; From here on the location counter is a real address rather than an offset,
; nothing more counts towards the size of the protected image, and labels are
; absolute. That rule keeps both passes saying the same thing.

ASM_D_ORG
      JSR   ASM_EXPR
      LDA   ASM_PAS           ; only pass 1 measures anything. pass 2 runs the
      CMP   #$02              ; same ORG again, with the location counter on
      BEQ   asm_org_set       ; real addresses, and would overwrite the answer
                              ; with one of them
      LDA   ASM_REL           ; the first ORG is where the protected image
      BEQ   asm_org_set       ; stops growing, so freeze its size here. a
                              ; later one changes nothing, we are already
                              ; absolute and the size is already settled
      LDA   ASM_LC
      STA   ASM_SIZ
      LDA   ASM_LC+1
      STA   ASM_SIZ+1

asm_org_set
      LDA   ASM_VAL
      STA   ASM_LC
      LDA   ASM_VAL+1
      STA   ASM_LC+1
      STZ   ASM_REL
      RTS

; ---------------------------------------------------------------------------
; ASM_LISTLINE   show what the line just assembled into
;
; Pass 2 only, and only when asked. Reads the bytes back out of memory rather
; than remembering them, which costs nothing and shows exactly what landed.
; ---------------------------------------------------------------------------

ASM_LISTLINE
      LDA   ASM_PAS
      CMP   #$02
      BNE   asm_ll_out

      LDA   ASM_LST
      BEQ   asm_ll_out

      LDA   ASM_LC0           ; nothing emitted, nothing to show
      CMP   ASM_LC
      BNE   asm_ll_go

      LDA   ASM_LC0+1
      CMP   ASM_LC+1
      BEQ   asm_ll_out

asm_ll_go
      LDA   ASM_LC0+1
      JSR   ASM_HEX2
      LDA   ASM_LC0
      JSR   ASM_HEX2
      JSR   ASM_SP
      JSR   ASM_SP

      LDY   #$00              ; up to four bytes of what was emitted
asm_ll_by
      CPY   #$04
      BCS   asm_ll_pad

      JSR   asm_ll_more
      BCC   asm_ll_pad

      PHY
      LDA   (ASM_LC0),Y
      JSR   ASM_HEX2
      JSR   ASM_SP
      PLY
      INY
      BRA   asm_ll_by

asm_ll_pad
      CPY   #$04
      BCS   asm_ll_src

      JSR   ASM_SP
      JSR   ASM_SP
      JSR   ASM_SP
      INY
      BRA   asm_ll_pad

asm_ll_src
      JSR   ASM_SP            ; same two column gap the disassembler leaves
      JSR   ASM_SP
      LDY   #$00
asm_ll_txt
      LDA   (ASM_WRK),Y
      BEQ   asm_ll_nl

      PHY
      JSR   LAB_PRNA
      PLY
      INY
      BRA   asm_ll_txt

asm_ll_nl
      JMP   LAB_CRLF

asm_ll_out
      RTS

; carry set if ASM_LC0+Y is still inside what this line emitted

asm_ll_more
      TYA
      CLC
      ADC   ASM_LC0
      TAX
      LDA   ASM_LC0+1
      ADC   #$00
      CMP   ASM_LC+1
      BCC   asm_ll_yes
      BNE   asm_ll_no

      CPX   ASM_LC
      BCC   asm_ll_yes

asm_ll_no
      CLC
      RTS

asm_ll_yes
      SEC
      RTS

; print A as two hex digits, and a space

ASM_HEX2
      PHA
      LSR
      LSR
      LSR
      LSR
      JSR   asm_hx2d
      PLA
asm_hx2d
      AND   #$0F
      CMP   #$0A
      BCC   asm_hx2o

      ADC   #$06              ; carry is set here, so seven in all
asm_hx2o
      ADC   #'0'
      JMP   LAB_PRNA

ASM_SP
      LDA   #' '
      JMP   LAB_PRNA

; ---------------------------------------------------------------------------
; report where the image landed, after an ASSEMBLE that was asked to list
; ---------------------------------------------------------------------------

ASM_REPORT
      LDA   #<asm_msg_at
      LDY   #>asm_msg_at
      JSR   LAB_18C3
      LDA   ASM_BAS+1
      JSR   ASM_HEX2
      LDA   ASM_BAS
      JSR   ASM_HEX2
      LDA   #<asm_msg_sz
      LDY   #>asm_msg_sz
      JSR   LAB_18C3
      LDX   ASM_SIZ
      LDA   ASM_SIZ+1
      JSR   LAB_295E
      JMP   LAB_CRLF

asm_msg_at
      .byte $0D,$0A,"CODE AT $",$00
asm_msg_sz
      .byte ", ",$00

; ---------------------------------------------------------------------------
; SYM("NAME")
;
; The string is already evaluated on entry, LAB_PPFS having been named as this
; function's pre-process in LAB_FTPL. Pop it, find it, and hand the address
; back in FAC1.
; ---------------------------------------------------------------------------

LAB_SYM
      JSR   LAB_22B6          ; A = length, pointer in ut1_pl
      STA   ASM_FL
      LDA   ASM_FLG           ; nothing has been assembled yet
      BPL   asm_sym_no

      LDA   ASM_FL
      BEQ   asm_sym_no        ; the empty string is in no symbol table

; ASM_LOOKUP reads the name out of the work buffer, so copy it there. it is
; ours to use - it only ever holds one line at a time, and no assembly is
; running while this is called

      LDA   ASM_FL
      CMP   #ASM_NAMSZ
      BCC   asm_sym_len

      LDA   #ASM_NAMSZ
      STA   ASM_FL

asm_sym_len
      STZ   ASM_FS
      LDY   #$00
asm_sym_cp
      CPY   ASM_FL
      BCS   asm_sym_find

      LDA   (ut1_pl),Y
      CMP   #'a'              ; a name typed in lower case still matches
      BCC   asm_sym_st
      CMP   #'z'+1
      BCS   asm_sym_st
      AND   #$DF
asm_sym_st
      STA   (ASM_WRK),Y
      INY
      BRA   asm_sym_cp

asm_sym_find
      JSR   ASM_LOOKUP
      BCC   asm_sym_no

      LDY   #$09              ; LAB_AYFC wants the high byte in A and the low
      LDA   (ASM_SPT),Y       ; byte in Y, the way DEEK hands it over, and it
      PHA                     ; treats the pair as unsigned
      DEY
      LDA   (ASM_SPT),Y
      TAY
      PLA
      JMP   LAB_AYFC

asm_sym_no
      LDX   #ERRNUM_UL
      JMP   LAB_XERR          ; not the assembler's ASM_ERROR - there is no
                              ; line being assembled to name

; the opcode tables and the disassembler are included rather than linked as
; separate units, the same way min_mon.s includes basic.s. they reach straight
; into the zero page declared above, which would otherwise all have to be
; exported and imported back again

      .include "opcodes.s"
      .include "disasm.s"

.endif                        ; ASM_BUILT
