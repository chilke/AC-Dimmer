
#include "p16lf15323.inc"

SHARED_VARS udata_shr
Tmp1	res 1
Tmp2	res 1
Tmp3	res 1
Val	res 1
H	res 1
L	res 1

RESET_VECT CODE 0x0000
   goto START
   
ISR_VECT CODE 0x0004
ISR:
   banksel PIR0 ; Bank 14
   btfss PIR0, TMR0IF
   goto NO_TMR0IF
   banksel TMR0H ; Bank 11
   movlw 0xff
   movwf TMR0H
   movlw .11 ; 255-244
   movwf TMR0L
   banksel LATA ; Bank 0
   movlw b'00100000'
   xorwf LATA, f
   banksel PIR0 ; Bank 14
   bcf PIR0, TMR0IF
NO_TMR0IF:
   ;banksel PIR2 ; Bank 14 No way to get here w/o bank 14 selected
   btfss PIR2, ZCDIF
   retfie ; TODO - Update to goto if further logic added
   bcf PIR2, ZCDIF
   banksel LATC ; Bank 0
   bcf LATC, LATC0
   banksel ZCDCON ; Bank 18
   btfss ZCDCON, ZCDOUT
   retfie ; TODO - Update to goto if further logic added
   banksel LATC ; Bank 0
   bsf LATC, LATC0
   retfie
;End interrupt routine

;nibbleToHex
;Parameter nibble passed in wreg
;Return passed in wreg
;Uses Tmp1 (nibble) and Tmp2 (return)
nibbleToHex:
    movwf Tmp1 ;Nibble value
    movlw a'0'
    movwf Tmp2 ;Temporary return value
    movlw .10
    subwf Tmp1, w ;nibble value - 10
    btfss STATUS, C ;carry means no borrow so nibble value >= 10
    goto UNDER_10
    movwf Tmp1 ;wreg already contains nibble-10
    movlw a'A'
    movwf Tmp2
UNDER_10:
    movf Tmp1, w
    addwf Tmp2, w
    return
;End nibbleToHex
   
;sendChar
;Parameter c passed in wreg
sendChar:
    banksel PIR3 ; Bank 14
WAIT:
    btfss PIR3, TX1IF
    goto WAIT ;Loop until TX1IF is set and we're ready to write
    
    banksel TX1REG ; Bank 2
    movwf TX1REG
    return
    
;sendInt
;Parameter i passed in wreg
;Uses Tmp3 i
;NIBBLE_TO_HEX uses Tmp1, Tmp2
sendInt:
    movwf Tmp3
    swapf Tmp3, w
    andlw 0x0F
    call nibbleToHex
    call sendChar
    movf Tmp3, w
    andlw 0x0F
    call nibbleToHex
    call sendChar
    return
    
;hexToNibble
;Parameter h passed in wreg
;Return value in wreg
;Uses Tmp1 (h parameter)
hexToNibble:
    movwf Tmp1 ;h
    movlw a'A'
    subwf Tmp1, w ; h - 'A'
    btfsc STATUS, C ; C clear means borrow or 'A' > h
    goto ALPHA_HEX_H
    movlw a'0'
    subwf Tmp1, w ; h - '0'
    return
ALPHA_HEX_H:
    addlw .10 ; Add 10 for A-F, w already contained h - 'A'
    return
;End hexToNibble
    
    
START:
    ;Setup analog select registers
    ;ZCD on RA2 must have analog enabled
    banksel ANSELA ;Bank 62
    clrf ANSELA
    clrf ANSELC
    bsf ANSELA, ANSA2
    ;Setup PPS outputs
    ;0f-EUSART TX on RC4
    movlw 0x0f
    movwf RC4PPS
    
    ;Setup I/O Pins, all output 0 by default
    ;RA2 is ZCD and must be input
    ;RC5 is EUSART RX
    banksel LATA; Bank 0
    clrf LATA
    clrf LATC
    clrf TRISA
    clrf TRISC
    bsf TRISA, TRISA2
    bsf TRISC, TRISC5
    
    ;Setup PPS inputs
    ;EUSART TX on RC4
    ;EUSART RX on RC5
    banksel TX1CKPPS ; Bank 61
    movlw 0x14
    movwf TX1CKPPS
    movlw 0x15
    movwf RX1DTPPS
    
    ;Setup EUSART
    banksel SP1BRGH ; Bank 2
    ;clrf SP1BRGH ; Resets to 0
    ;clrf SP1BRGL ; Resets to 0
    bsf SP1BRGL, 4 ; 16
    ;clrf BAUD1CON ; Resets to 0
    movlw b'00100100'
    movwf TX1STA
    movlw b'10010000'
    movwf RC1STA
    
    ;Setup Timer 0
    banksel T0CON0 ; Bank 11
    ;clrf T0CON0 ; Resets to 0
    bsf T0CON0, T016BIT
    movlw b'01001111'
    movwf T0CON1
    movlw 0xff
    movwf TMR0H
    movlw .11 ;255-244
    movwf TMR0L
    bsf T0CON0, T0EN
    
    ;Setup ZCD
    banksel ZCDCON ; Bank 18
    movlw b'10000011'
    movwf ZCDCON
    
    ;Setup Interrupts Global Bank
    bsf INTCON, PEIE
    bsf INTCON, GIE
    
    ;Setup Interrupts NonGlobal Bank
    banksel PIE0 ; Bank 14
    bsf PIE0, TMR0IE
    bsf PIE2, ZCDIE
    
MAIN_LOOP:
    swapf Val, w
    andlw 0x0F ; w contains high nibble
    call nibbleToHex ; w contains ascii for high nibble
    movwf H
    movf Val, w
    andlw 0x0F ; w contains low nibble
    call nibbleToHex ; w contains ascii for low nibble
    movwf L
    movf H, w
    call hexToNibble
    movwf H
    swapf H, f
    movf L, w
    call hexToNibble
    addwf H, w
    incf Val, f
    goto MAIN_LOOP
    
    
    END