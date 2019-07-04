; PIC16LF15323 Configuration Bit Settings
; Assembly source line config statements
#include "p16lf15323.inc"

; CONFIG1
; __config 0xD79C
 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINTPLL & _CLKOUTEN_OFF & _CSWEN_OFF & _FCMEN_OFF
; CONFIG2
; __config 0xF9FF
 __CONFIG _CONFIG2, _MCLRE_ON & _PWRTE_OFF & _LPBOREN_OFF & _BOREN_ON & _BORV_HI & _ZCD_ON & _PPS1WAY_ON & _STVREN_ON
; CONFIG3
; __config 0xFF9F
 __CONFIG _CONFIG3, _WDTCPS_WDTCPS_31 & _WDTE_OFF & _WDTCWS_WDTCWS_7 & _WDTCCS_SC
; CONFIG4
; __config 0xFFFF
 __CONFIG _CONFIG4, _BBSIZE_BB512 & _BBEN_OFF & _SAFEN_OFF & _WRTAPP_OFF & _WRTB_OFF & _WRTC_OFF & _WRTSAF_OFF & _LVP_ON
; CONFIG5
; __config 0xFFFF
 __CONFIG _CONFIG5, _CP_OFF

   END