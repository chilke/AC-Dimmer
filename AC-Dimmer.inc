
#define F0_CUR_DELAY_MASK 0x3
#define F0_CUR_DELAY_0 0
#define F0_CUR_DELAY_1 1
#define F0_TURN_ON_0_CH0 2
#define F0_TURN_ON_0_CH1 3
#define F0_TURN_ON_1_CH0 4
#define F0_TURN_ON_1_CH1 5
#define F0_ALWAYS_ON_CH0 6
#define F0_ALWAYS_ON_CH1 7
    
#define F1_TURN_OFF_2 0
    
#define CH0_REG LATA
#define CH1_REG LATA
#define CH0_BIT LATA4
#define CH1_BIT LATA5
   
#define ZCD_OFFSET_DELAY 0xFF74 ;Complement 140
    
#define ZCD_REG LATC
#define ZCD_BIT LATC2
    
#define CMP_16_GT 1
#define CMP_16_EQ 2
#define CMP_16_LT 4
    
#define CMP_16_GT_BIT 0
#define CMP_16_EQ_BIT 1
#define CMP_16_LT_BIT 2

#define MAX_DELAY .8192
    
#define DELAY_MAX_H 
    
#define CMD_ACK a'K'
#define CMD_NACK a'N'
    
#define CMD_START a'S'
#define CMD_STOP a'P'

#define CMD_SET_CH0 .0
#define CMD_SET_CH1 .1
#define CMD_ACTIVATE .2
#define CMD_MAX .2