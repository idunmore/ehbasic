100 REM Print a string from assembly language
110 REM
120 REM $0207 is EhBASIC's output vector, VEC_OUT.  Going through it,
130 REM rather than calling CHROUT directly, means this will keep
140 REM working wherever the serial output routne happens to be in 
150 REM that ROM build.
160 REM
170 REM The "|" after each line number is an option indent prefix.
180 REM Without it EhBASIC would eat the spaces and everything would
190 REM be hard-left
200 REM
210 ASM
220 ; Showing EQU usage, making CHROUT a sugar-alias for VEC_OUT
230 CHROUT EQU $0207
240 ; Labels can have their own line ...
250 START
260 |      LDX #$00
270 ; ... or share a line with instructions ...
280 LOOP   LDA MSG,X
290 |      BEQ DONE
300 |      JSR COUT
310 |      INX
320 |      BNE LOOP
330 ; ... and trailing colons are supported, but ignored ...
340 DONE:
350 |      RTS
360 COUT   JMP (CHROUT) ; CHROUT = VEC_OUT, so jump indirectly
370 ;
380 MSG    TEXT "Hello from EhBASIC Assembler ..."
390 |      BYTE $0D,$0A,$00
400 ENDASM
410 REM SYM("<symbol_name>") gets the address of any symbol, so we
420 REM can use it for a CALL ...
430 CALL SYM("START")
440 REM ... or to share data between ASM and BASIC.
450 REM Convert lower case ASM string to uppercase
460 MSG=SYM("MSG")
470 C=PEEK(MSG)
480 IF C=0 THEN 530
490 IF C>=97 AND C<=122 THEN C=C-32
500 POKE MSG,C
510 MSG=MSG+1
520 GOTO 470
530 CALL SYM("START")
