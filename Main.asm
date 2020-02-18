;TODO - Test interrupts on device
;TODO - Refactor ports used to match 8 pin package
;       EUSART shares ICSP pins RA0/RA1
;       ZCD remains the same RA2
;       CH0/1 remains the same RA4/RA5

#define DEBUG
    
#include "p16lf15323.inc"
#include "AC-Dimmer.inc"
    
BANK0_VARS udata 0x0020 ;20-6F
Ch0Delay	res 2 ;20
Ch1Delay	res 2 ;22
	
Tmp16a		res 2 ;24
Tmp16b		res 2 ;26
		
Cmd		res 1 ;28
CmdVal		res 2 ;29
RcvCnt		res 1 ;2B
Rx		res 1 ;2C
	
		
SHARED_VARS udata_shr
Tmp0		res 1 ;1
Tmp1		res 1 ;2
Tmp2		res 1 ;3
	
Delay0		res 2 ;5
Delay1		res 2 ;7
Delay2		res 2 ;9
	
Flags0		res 1 ;B
Flags1		res 1 ;C

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
    banksel PIR2 ;Bank 14
#ifdef DEBUG
    btfss PIR0, IOCIF
#else
    btfss PIR2, ZCDIF
#endif
    goto ISR_NO_ZCD
    bcf PIR2, ZCDIF
#ifdef DEBUG
    banksel IOCCF
    bcf IOCCF, IOCCF0
#endif
    banksel TMR0H ;Bank 11
    movlw high ZCD_OFFSET_DELAY
    movwf TMR0H
    movlw low ZCD_OFFSET_DELAY
    movwf TMR0L
    movlw ~F0_CUR_DELAY_MASK
    andwf Flags0, f
    btfss Flags1, F1_UPDATE_DELAYS
    retfie
    ;banksel T0CON0 ;Bank 11 Already selected
    bsf T0CON0, T0EN
    call updateDelays
    bcf Flags1, F1_UPDATE_DELAYS
    retfie
ISR_NO_ZCD:
    ;banksel PIR0 ;Bank 14
    bcf PIR0, TMR0IF
    movlw F0_CUR_DELAY_MASK
    andwf Flags0, w
    banksel TMR0H ;Bank 11
    brw
    goto ISR_CD_0
    goto ISR_CD_1
    goto ISR_CD_2
ISR_CD_3:
    banksel CH0_REG ;Bank 0
    btfss Flags0, F0_ALWAYS_ON_CH0
    bcf CH0_REG, CH0_BIT
    btfss Flags0, F0_ALWAYS_ON_CH1
    bcf CH1_REG, CH1_BIT
    retfie
ISR_CD_2:
    incf Flags0, f ;This only increments current delay
    ;banksel TMR0H ;Bank 11
    movf Delay2+.1, w
    movwf TMR0H
    movf Delay2, w
    movwf TMR0L
    banksel CH0_REG ;Bank 0
    btfsc Flags0, F0_TURN_ON_1_CH0
    bsf CH0_REG, CH0_BIT
    btfsc Flags0, F0_TURN_ON_1_CH1
    bsf CH1_REG, CH1_BIT
    btfss Flags1, F1_TURN_OFF_2
    retfie
    btfss Flags0, F0_ALWAYS_ON_CH0
    bcf CH0_REG, CH0_BIT
    btfss Flags0, F0_ALWAYS_ON_CH1
    bcf CH1_REG, CH1_BIT
    retfie
ISR_CD_1:
    incf Flags0, f
    ;banksel TMR0H ;Bank 11
    movf Delay1+.1, w
    movwf TMR0H
    movf Delay1, w
    movwf TMR0L
    banksel CH0_REG ;Bank 0
    btfsc Flags0, F0_TURN_ON_0_CH0
    bsf CH0_REG, CH0_BIT
    btfsc Flags0, F0_TURN_ON_0_CH1
    bsf CH1_REG, CH1_BIT
    retfie
ISR_CD_0:
    incf Flags0, f
    banksel TMR0H ;Bank 11
    movf Delay0+.1, w
    movwf TMR0H
    movf Delay0, w
    movwf TMR0L
    banksel ZCDCON
    btfss ZCDCON, ZCDOUT
    goto ZCD_LOW
    banksel ZCD_REG
    bsf ZCD_REG, ZCD_BIT
    retfie
ZCD_LOW:
    banksel ZCD_REG
    bcf ZCD_REG, ZCD_BIT
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

;complementDelays
complementDelays:
    comf Delay0, f
    comf Delay0+.1, f
    comf Delay1, f
    comf Delay1+.1, f
    comf Delay2, f
    comf Delay2+.1, f
    return
    
;updateDelays
;No parameters
;No return value
;Called from ISR so should not touch any shared variables
updateDelays:
    ;Clear some stuff
    ;banksel Flags0 ;Shared Bank
    clrf Flags0
    clrf Flags1
    movlw 0xFF
    movwf Delay0
    movwf Delay0+.1
    movwf Delay1
    movwf Delay1+.1
    movwf Delay2
    movwf Delay2+.1
    
    banksel CH0_REG ;Bank 0
    bcf CH0_REG, CH0_BIT
    bcf CH1_REG, CH1_BIT
    
    ;If Ch0Delay == 0
    banksel Ch0Delay ;Bank 0
    Cmp16VtoL Ch0Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_0
    ;Ch0Delay == 0 so it is always on
    bsf Flags0, F0_ALWAYS_ON_CH0
    ;banksel CH0_REG ;Bank 0
    bsf CH0_REG, CH0_BIT
    ;If Ch1Delay == 0
    Cmp16VtoL Ch1Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH1_NE_0
    ;Ch1Delay == 0 so it is always on
    bsf Flags0, F0_ALWAYS_ON_CH1
    ;banksel CH1_REG ;Bank 0
    bsf CH1_REG, CH1_BIT
    ;Both Channels are always on, gotta disable timer
    goto UD_DISABLE_T0
UD_CH1_NE_0:
    ;Check if Ch1 is Max
    Cmp16VtoL Ch1Delay, MAX_DELAY
    btfsc WREG, CMP_16_EQ_BIT
    goto UD_DISABLE_T0
    ;Ch0Delay == 0 and Ch1Delay != 0
    Copy16 Delay0, Ch1Delay
    bsf Flags0, F0_TURN_ON_0_CH1
    Sub16ReLmV Delay1, MAX_DELAY, Ch1Delay
    bsf Flags1, F1_TURN_OFF_2
    goto UD_ENDING
UD_CH0_NE_0:
    ;If Ch1Delay == 0
    Cmp16VtoL Ch1Delay, .0
    btfss WREG, CMP_16_EQ_BIT
    goto UD_BOTH_NE_0
    ;Ch1Delay == 0 so it is always on
    bsf Flags0, F0_ALWAYS_ON_CH1
    ;banksel CH1_REG ;Bank 0
    bsf CH1_REG, CH1_BIT
    ;Check if Ch0 is Max
    Cmp16VtoL Ch0Delay, MAX_DELAY
    btfsc WREG, CMP_16_EQ_BIT
    goto UD_DISABLE_T0
    ;Ch0Delay != 0 so setup delays
    Copy16 Delay0, Ch0Delay
    bsf Flags0, F0_TURN_ON_0_CH0
    Sub16ReLmV Delay1, MAX_DELAY, Ch0Delay
    bsf Flags1, F1_TURN_OFF_2
    goto UD_ENDING
UD_BOTH_NE_0:
    ;If Ch0Delay == Ch1Delay
    Cmp16VtoV Ch0Delay, Ch1Delay
    btfss WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_CH1
    Cmp16VtoL Ch0Delay, MAX_DELAY
    btfsc WREG, CMP_16_EQ_BIT
    goto UD_DISABLE_T0
    Copy16 Delay0, Ch0Delay
    bsf Flags0, F0_TURN_ON_0_CH0
    bsf Flags0, F0_TURN_ON_0_CH1
    Sub16ReLmV Delay1, MAX_DELAY, Ch0Delay
    bsf Flags1, F1_TURN_OFF_2
    goto UD_ENDING
UD_CH0_NE_CH1:
    ;WREG still contains results of CH0Delay cmp to Ch1Delay
    btfss WREG, CMP_16_GT_BIT
    goto UD_CH0_LT_CH1
    ;Ch0Delay > Ch1Delay
    Copy16 Delay0, Ch1Delay
    bsf Flags0, F0_TURN_ON_0_CH1
    Cmp16VtoL Ch0Delay, MAX_DELAY
    btfsc WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_CH1_MAX
    Sub16ReVmV Delay1, Ch0Delay, Ch1Delay
    bsf Flags0, F0_TURN_ON_1_CH0
    Sub16ReLmV Delay2, MAX_DELAY, Ch0Delay
    goto UD_ENDING
UD_CH0_LT_CH1:
    ;Ch1Delay > Ch0Delay
    Copy16 Delay0, Ch0Delay
    bsf Flags0, F0_TURN_ON_0_CH0
    Cmp16VtoL Ch1Delay, MAX_DELAY
    btfsc WREG, CMP_16_EQ_BIT
    goto UD_CH0_NE_CH1_MAX
    Sub16ReVmV Delay1, Ch1Delay, Ch0Delay
    bsf Flags0, F0_TURN_ON_1_CH1
    Sub16ReLmV Delay2, MAX_DELAY, Ch1Delay
UD_ENDING:
    call complementDelays
    return
UD_CH0_NE_CH1_MAX:
    ;Could try to add logic here to turn off output immediately, but meh
    Sub16ReLmV Delay1, MAX_DELAY, Delay0
    bsf Flags1, F1_TURN_OFF_2
    goto UD_ENDING
UD_DISABLE_T0:
    banksel T0CON0 ;Bank 11
    bcf T0CON0, T0EN
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
    bsf TRISC, TRISC0
    
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
    ;Clk Fosc/4 8MHz
    ;Pre 1:8 1MHz or 1us period
    ;16 Bit enabled
    banksel T0CON0 ; Bank 11
    ;clrf T0CON0 ; Resets to 0
    bsf T0CON0, T016BIT
    movlw b'01000011'
    movwf T0CON1
    
    ;Setup ZCD
    banksel ZCDCON ; Bank 18
    movlw b'10000011'
    movwf ZCDCON

#ifdef DEBUG
    ;Setup IOC for Debug
    banksel IOCCP
    bsf IOCCP, IOCCP0
    bsf IOCCN, IOCCN0
#endif
    
    ;Setup Interrupts Global Bank
    bsf INTCON, PEIE
    bsf INTCON, GIE
    
    ;Setup Interrupts NonGlobal Bank
    banksel PIE0 ; Bank 14
    bsf PIE0, TMR0IE
    bsf PIE2, ZCDIE
#ifdef DEBUG
    bsf PIE0, IOCIE
#endif
    
    banksel RcvCnt ;Bank 0
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
    banksel Rx ;Bank 0
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
    banksel Rx ;Bank 0
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
    banksel RcvCnt ;Bank 0
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
    ;banksel Ch0Delay ; Bank 0 already set
    brw
    goto SET_CH0
    goto SET_CH1
;if more commands are added, change this to goto ACTIVATE
ACTIVATE:
    ;Set flag to indicate we need to update delays
    bsf Flags1, F1_UPDATE_DELAYS
    goto CMD_PROCESSED
SET_CH1:
    btfsc Flags1, F1_UPDATE_DELAYS
    goto CMD_FAILED
    ;banksel Ch1Delay ; Bank 0 already set
    Cmp16VtoL CmdVal, MAX_DELAY
    btfsc WREG, CMP_16_GT_BIT
    goto CMD_FAILED
    Copy16 Ch1Delay, CmdVal
    movf Ch1Delay+.1, w
    call sendInt
    banksel Ch1Delay ;Bank 0
    movf Ch1Delay, w
    call sendInt
    banksel Ch1Delay ;Bank 0
    goto CMD_PROCESSED
SET_CH0:
    btfsc Flags1, F1_UPDATE_DELAYS
    goto CMD_FAILED
    ;banksel Ch0Delay ; Bank 0 already set
    Cmp16VtoL CmdVal, MAX_DELAY
    btfsc WREG, CMP_16_GT_BIT
    goto CMD_FAILED
    Copy16 Ch0Delay, CmdVal
    movf Ch0Delay+.1, w
    call sendInt
    banksel Ch0Delay ;Bank 0
    movf Ch0Delay, w
    call sendInt
    banksel Ch0Delay ;Bank 0
    goto CMD_PROCESSED
;No receive byte, check for overflow error here
CHECK_OERR:
    banksel RC1STA
    btfss RC1STA, OERR
    goto MAIN_LOOP
;Has OERR, send NACK and clear/reset CREN to clear OERR
    movlw CMD_NACK
    call sendChar
    banksel RC1STA
    bcf RC1STA, CREN
    bsf RC1STA, CREN
    goto MAIN_LOOP

CMD_PROCESSED:
    movlw CMD_ACK
    call sendChar
    banksel RcvCnt ;Bank 0
    clrf RcvCnt
    goto MAIN_LOOP
    
CMD_FAILED:
    movlw CMD_NACK
    call sendChar
    banksel RcvCnt ;Bank 0
    clrf RcvCnt
    goto MAIN_LOOP
    
    END