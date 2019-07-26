
#include "p16lf15323.inc"
#include "AC-Dimmer.inc"
    
BANK0_VARS udata 0x0020 ;20-6F
Ch0Delay	res 2 ;20
Ch1Delay	res 2 ;22

Delay0		res 2 ;24
Delay1		res 2 ;26
Delay2		res 2 ;28

TurnOn0		res 1 ;29
TurnOn1		res 1 ;2A

AlwaysOn	res 1 ;2B
		
CurrentDelay	res 1 ;2C
	
TurnOffDelay	res 1 ;2D
	
Tmp16a		res 2 ;2E
Tmp16b		res 2 ;30
	
SHARED_VARS udata_shr
Tmp0	res 1 ;1
Tmp1	res 1 ;2
Tmp2	res 1 ;3
Cmd	res 1 ;4
CmdVal	res 2 ;6
RcvCnt	res 1 ;7
Rx	res 1 ;8

;Load16 - load the 16 bit literal h,l into v
;Bank for v must be selected
Load16 macro Va, La
    movlw high La
    movwf Va+.1
    movlw low La
    movwf Va
    endm
    
;Copy16 - copy the 16 bit variable Vb into Va
;Va and Vb must be in the same bank and it must be selected
Copy16 macro Va, Vb
    movf Vb, w
    movwf Va
    movf Vb+.1, w
    movwf Va+.1
    endm
	
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
;Uses Tmp0 (nibble) and Tmp1 (return)
nibbleToHex:
    movwf Tmp0 ;Nibble value
    movlw a'0'
    movwf Tmp1 ;Temporary return value
    movlw .10
    subwf Tmp0, w ;nibble value - 10
    btfss STATUS, C ;carry means no borrow so nibble value >= 10
    goto UNDER_10
    movwf Tmp0 ;wreg already contains nibble-10
    movlw a'A'
    movwf Tmp1
UNDER_10:
    movf Tmp0, w
    addwf Tmp1, w
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
;Uses Tmp2 i
;NIBBLE_TO_HEX uses Tmp0, Tmp1
sendInt:
    movwf Tmp2
    swapf Tmp2, w
    andlw 0x0F
    call nibbleToHex
    call sendChar
    movf Tmp2, w
    andlw 0x0F
    call nibbleToHex
    call sendChar
    return
    
;hexToNibble
;Parameter h passed in wreg
;Return value in wreg
;Uses Tmp0 (h parameter)
hexToNibble:
    movwf Tmp0 ;h
    movlw a'A'
    subwf Tmp0, w ; h - 'A'
    btfsc STATUS, C ; C clear means borrow or 'A' > h
    goto ALPHA_HEX_H
    movlw a'0'
    subwf Tmp0, w ; h - '0'
    return
ALPHA_HEX_H:
    addlw .10 ; Add 10 for A-F, w already contained h - 'A'
    return
;End hexToNibble

;compare16s
;Parameters passed in Tmp16a/b
;Return value passed in w using CMP_16_* bits
;Must have Tmp16a/b bank selected when calling
;Compares a to b so a > b = CMP_16_GT and a < b = CMP_16_LT
compare16s:
    movf Tmp16b+.1, w
    subwf Tmp16a+.1, w ;w = Tmp16aH-Tmp16bH
    btfss STATUS, Z
    goto CMP_16_NE ;Zero clear means highs weren't equal
    movf Tmp16b, w
    subwf Tmp16a, w ;w = Tmp16aL-Tmp16bL
    btfsc STATUS, Z
    retlw CMP_16_EQ ;Zero now means highs and lows both equal
CMP_16_NE:
    btfsc STATUS, C
    retlw CMP_16_GT ;Carry set means no borrow so a > b
    retlw CMP_16_LT ;Carry clear means borrow so b > a
    
;Cmp16VtoV - Compare 16 bit var to 16 bit var
;Va and Vb must be in same bank as Tmp16a/b and that bank must be selected
Cmp16VtoV macro Va, Vb
    Copy16 Tmp16a, Va
    Copy16 Tmp16b, Vb
    call compare16s
    endm
    
;Cmp16VtoL - Compare 16 bit var to 16 bit literal
;Va must be in the same bank as Tmp16a/b and that bank must be selected
Cmp16VtoL macro Va, Lb
    Copy16 Tmp16a, Va
    Load16 Tmp16b, Lb
    call compare16s
    endm
    
;Cmp16LtoL - Compare 16 bit literal to 16 bit literal
;Tmp16a/b bank must be selected
Cmp16LtoL macro La, Lb
    Load16 Tmp16a, La
    Load16 Tmp16b, Lb
    call compare16s
    endm

;Sub16ReVmV - Subtract 16 bit variable from 16 bit variable
;Result is stored in R
Sub16ReVmV macro R, Va, Vb
    movf Vb, w
    subwf Va, w
    movwf R ;RL = VaL - VbL
    movf Vb+.1, w
    subwfb Va+.1, w
    movwf R+.1 ;RH = VaH - VbH - B
    endm
    
;Sub16ReLmV - Subtract 16 bit variable from 16 bit literal
;Result is stored in R
;Uses Tmp0
Sub16ReLmV macro R, L, V
    movlw low L
    movwf Tmp0
    movf V, w
    subwf Tmp0, w
    movwf R ;RL = LL - VL
    movlw high L
    movwf Tmp0
    movf V+.1, w
    subwfb Tmp0, w
    movwf R+.1 ;RH = LH - VH - B
    endm
    
;updateDelays
;No parameters
;No return value
updateDelays:
    ;Disable interrupts
    bcf INTCON, GIE
    
    ;Clear some stuff
    banksel TurnOn0 ;Bank 0
    clrf TurnOn0
    clrf TurnOn1
    clrf AlwaysOn
    clrf Delay1
    clrf Delay1+.1
    clrf Delay2
    clrf Delay2+.1
    
    ;If Ch0Delay == 0
    Cmp16VtoL Ch0Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_0
    ;Ch0Delay == 0 so it is always on
    bsf AlwaysOn, 0
    ;If Ch1Delay == 0
    Cmp16VtoL Ch1Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH1_NE_0
    ;Ch1Delay == 0 so it is always on
    bsf AlwaysOn, 1
    ;Set single delay to max and we're done
    Load16 Delay0, MAX_DELAY
    goto UD_ENDING
UD_CH1_NE_0:
    ;Ch0Delay == 0 and Ch1Delay != 0
    Copy16 Delay0, Ch1Delay
    bsf TurnOn0, 1
    Sub16ReLmV Delay1, MAX_DELAY, Ch1Delay
    movlw .1
    movwf TurnOffDelay
    goto UD_ENDING
UD_CH0_NE_0:
    ;If Ch1Delay == 0
    Cmp16VtoL Ch1Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_BOTH_NE_0
    ;Ch1Delay == 0 so it is always on
    bsf AlwaysOn, 1
    ;Ch0Delay != 0 so setup delays
    Copy16 Delay0, Ch0Delay
    bsf TurnOn0, 0
    Sub16ReLmV Delay1, MAX_DELAY, Ch0Delay
    movlw .1
    movwf TurnOffDelay
    goto UD_ENDING
UD_BOTH_NE_0:
    ;If Ch0Delay == Ch1Delay
    Cmp16VtoV Ch0Delay, Ch1Delay
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_CH1
    Copy16 Delay0, Ch0Delay
    bsf TurnOn0, 0
    bsf TurnOn1, 1
    Sub16ReLmV Delay1, MAX_DELAY, Ch0Delay
    movlw .1
    movwf TurnOffDelay
    goto UD_ENDING
UD_CH0_NE_CH1:
    ;WREG still contains results of CH0Delay cmp to Ch1Delay
    btfss WREG, CMP_16_GT_BIT
    goto UD_CH0_LT_CH1
    ;Ch0Delay > Ch1Delay
    Copy16 Delay0, Ch1Delay
    bsf TurnOn0, 1
    Sub16ReVmV Delay1, Ch0Delay, Ch1Delay
    bsf TurnOn1, 0
    Sub16ReLmV Delay2, MAX_DELAY, Ch0Delay
    goto UD_CH0_NE_CH1_ENDING
UD_CH0_LT_CH1:
    ;Ch1Delay > Ch0Delay
    Copy16 Delay0, Ch0Delay
    bsf TurnOn0, 0
    Sub16ReVmV Delay1, Ch1Delay, Ch0Delay
    bsf TurnOn1, 1
    Sub16ReLmV Delay2, MAX_DELAY, Ch1Delay
UD_CH0_NE_CH1_ENDING:
    movlw .2
    movwf TurnOffDelay
UD_ENDING:
    ;Clear timer to ensure it won't immediately roll over
    banksel TMR0H ;Bank 11
    clrf TMR0H
    clrf TMR0L
    
    ;Clear any interrupts which occurred while we were processing
    banksel PIR0 ;Bank 14
    bcf PIR0, TMR0IF
    ;banksel PIR2 ;Bank 14
    bcf PIR2, ZCDIF
    
    ;Finally reenable interrupts
    bsf INTCON, GIE
    return
    
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
    
    clrf RcvCnt
    
MAIN_LOOP:
    banksel PIR3 ; Bank 14
;Check if we have a receive byte
;if PIR3.RC1IF
    btfss PIR3, RC1IF
    goto CHECK_OERR
;We have a receive byte
;Check for framing error on this byte
    banksel RC1STA ; Bank 2
    btfss RC1STA, FERR
    goto NO_FERR
;Has FERR, read byte, reset receive count, send NACK
    ;banksel RC1REG ; Bank 2 already selected
    movf RC1REG, f
    movf Rx, f
    btfss STATUS, Z
    goto CMD_FAILED
    movf RcvCnt, f
    btfss STATUS, Z
    goto CMD_FAILED
    goto MAIN_LOOP
NO_FERR:
    ;banksel RC1REG ; Bank 2 already selected
    movf RC1REG, w
    movwf Rx
    ;First check for Start Byte no matter RcvCnt
    movlw CMD_START
    subwf Rx, w
    btfss STATUS, Z
    goto NOT_START_BYTE
    ;So we got a start byte, check if RcvCnt is 0
    movlw CMD_NACK
    movf RcvCnt, f
    btfss STATUS, Z
    call sendChar ;Send NACK if RcvCnt was not 0
    clrf RcvCnt
    incf RcvCnt, f
    goto MAIN_LOOP
NOT_START_BYTE:
    movlw 0x07
    andwf RcvCnt, w ; mask in first 3 bits just in case
    incf RcvCnt, f
    brw
    goto RCV_CNT_0
    goto RCV_CNT_1
    goto RCV_CNT_2
    goto RCV_CNT_3
    goto RCV_CNT_4
    goto RCV_CNT_5
    goto RCV_CNT_6
;Default RcvCnt 6 or 7 means we've received too much, should never happen
RCV_CNT_0:
    ;If we got here we know this isn't a start byte
    ;Check for break character
    movf Rx, f
    btfss STATUS, Z
    goto CMD_FAILED
    clrf RcvCnt
    goto MAIN_LOOP
RCV_CNT_1:
    ;This is the high nibble of the command byte
    movf Rx, w
    call hexToNibble
    movwf Cmd
    swapf Cmd, f
    goto MAIN_LOOP
RCV_CNT_2:
    ;This is the low nibble of the command byte
    movf Rx, w
    call hexToNibble
    addwf Cmd, f
    ;First check that command is within range
    movlw CMD_MAX+.1
    subwf Cmd, w ;Cmd - (CMD_MAX+1)
    ;This should generate Borrow or ~C if Cmd <= CMD_MAX
    btfsc STATUS, C
    goto CMD_FAILED ;Cmd > CMD_MAX
    goto MAIN_LOOP ;Cmd <= CMD_MAX
RCV_CNT_3:
    ;This is the high nibble of the high param value
    movf Rx, w
    call hexToNibble
    movwf CmdVal+.1
    swapf CmdVal+.1, f
    goto MAIN_LOOP
RCV_CNT_4:
    ;This is the low nibble of the high param value
    movf Rx, w
    call hexToNibble
    addwf CmdVal+.1, f
    goto MAIN_LOOP
RCV_CNT_5:
    ;This is the high nibble of the low param value
    movf Rx, w
    call hexToNibble
    movwf CmdVal
    swapf CmdVal, f
    goto MAIN_LOOP
RCV_CNT_6:
    ;This is the low nibble of the low param value
    movf Rx, w
    call hexToNibble
    addwf CmdVal, f
;We've already validated Cmd is <= CMD_MAX, so let's just start processing
    movf Cmd, w
;Might as well do this now since all paths ahead need it
    banksel Ch0Delay ; Bank 0
    brw
    goto SET_CH0
;if more commands are added, change this to goto SET_CH1
SET_CH1:
    ; banksel Ch1Delay ; Bank 0 already set above
    Cmp16VtoL CmdVal, MAX_DELAY
    btfss WREG, CMP_16_LT_BIT
    goto CMD_FAILED
    Copy16 Ch1Delay, CmdVal
    ;TODO call Update Delays
    goto CMD_PROCESSED
SET_CH0:
    ; banksel Ch0Delay ; Bank 0 already set above
    Cmp16VtoL CmdVal, MAX_DELAY
    btfss WREG, CMP_16_LT_BIT
    goto CMD_FAILED
    Copy16 Ch0Delay, CmdVal
    ;TODO call Update Delays
    goto CMD_PROCESSED
;No receive byte, check for overflow error here
CHECK_OERR:
    banksel RC1STA
    btfss RC1STA, OERR
    goto MAIN_LOOP
;Has OERR, send NACK and clear/reset CREN to clear OERR
    movlw CMD_NACK
    call sendChar
    bcf RC1STA, CREN
    bsf RC1STA, CREN
    goto MAIN_LOOP

CMD_PROCESSED:
    movlw CMD_ACK
    call sendChar
    clrf RcvCnt
    goto MAIN_LOOP
    
CMD_FAILED:
    movlw CMD_NACK
    call sendChar
    clrf RcvCnt
    goto MAIN_LOOP
    
    END