
; PIC16F73 Configuration Bit Settings

; ASM source line config statements

#include "p16f73.inc"

; CONFIG
; __config 0xFFF2
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _CP_OFF & _BOREN_ON


;    pinning
;   
;  RFID:
;    RC1  125kHz output
;    RC2  comparator input
;
;  EEPROM: (not used)
;    RC3  SCL
;    RC4  SDA
;
;  LED:
;    RA4  yellow, active low
;    RA5  green, active low
;
;  Buzzer:
;    RB1  active high
;
;  keypad:
;       RA0 RA3 RA2 RA1
;  RB4    M   1   2   3
;  RB5        4   5   6
;  RB6        7   8   9
;  RB7        *   0   #
;

; vars
K_DOWN      EQU 0x40 ; ASCII code of pressed key, set to 0 after parsing
K_WAIT      EQU 0x41 ; nonzero while waiting kbd to clear

TAG1	    EQU 0x50 ; parsed TAG
TAG2	    EQU 0x51
TAG3	    EQU 0x52
TAG4	    EQU 0x53
TAG5	    EQU 0x54

TEMP1       EQU 0x68
TEMP2       EQU 0x69
W_TEMP      EQU 0x70
STATUS_TEMP EQU 0x71 
PCLATH_TEMP EQU 0x72

CAPTURED    EQU 0x73
DSTATE      EQU 0x74
D_WAITLONG  EQU 1    ; set if we need long bit to sync up
D_NOLONG    EQU 0    ; set if next bit must be short (long would violate clocking)
D_PARSING   EQU 2    ; grabbing bitstream
D_PARSED    EQU 3    ; grabbed bitstream
SYNCBITS    EQU 0x75 ; syncbits grabbed
BITNO       EQU 0x76 ; bit number in stream
       
    radix dec ; end the madness ;)
    
    org 0x000
    goto main

    
    
    
; this interrupt routine takes care of decoding machester code received on CCP1
; modele. We are intrested in bitstream clocked at 125000/64 = ~1950 'hz'
; basically transitions should occur every ~256 or ~512 us
    
    org 0x004
    MOVWF W_TEMP ;Copy W to TEMP register
    SWAPF STATUS,W ;Swap status to be saved into W
    CLRF STATUS ;bank 0, regardless of current bank, Clears IRP,RP1,RP0
    MOVWF STATUS_TEMP ;Save status to bank zero STATUS_TEMP register
    MOVF PCLATH, W ;Only required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP ;Save PCLATH into W
    CLRF PCLATH ;Page zero, regardless of current page
    clrf TMR1L
    clrf TMR1H
    
    btfsc DSTATE,D_PARSED
    goto  _int_out
    
    movfw CCPR1L
    andlw 0xf0     ; we only care about high bits
    movwf CAPTURED
    xorlw 0x30
    bz    _int_shortp
    movfw CAPTURED
    xorlw 0x40
    bz    _int_shortp
    movfw CAPTURED
    xorlw 0x70
    bz    _int_longp
    movfw CAPTURED
    xorlw 0x80
    bz    _int_longp
    ; invalid pulse received
_int_reset
    clrf  DSTATE
    bsf   DSTATE,D_WAITLONG
    clrf  SYNCBITS
    clrf  BITNO
    goto  _int_out

_int_shortp
    btfsc DSTATE,D_WAITLONG
    goto  _int_out ; keep waiting
    movfw DSTATE
    xorlw 0x01  ; toggle D_NOLONG
    movwf DSTATE
    btfss DSTATE,0
    goto  int_decodebit
    goto  _int_out

_int_longp
    bcf   DSTATE,D_WAITLONG
    btfsc DSTATE,D_NOLONG
    goto  _int_reset ;manchester violation
    goto  int_decodebit
    
_int_out
    movfw CCP1CON
    xorlw 0x01
    movwf CCP1CON
    bcf   PIR1,CCP1IF

    MOVF  PCLATH_TEMP, W ;Restore PCLATH
    MOVWF PCLATH ;Move W into PCLATH
    SWAPF STATUS_TEMP,W ;Swap STATUS_TEMP register into W
;(sets bank to original state)
    MOVWF STATUS ;Move W into STATUS register
    SWAPF W_TEMP,F ;Swap W_TEMP
    SWAPF W_TEMP,W ;Swap W_TEMP into W
    retfie
    
int_decodebit
    btfsc DSTATE,D_PARSING
    goto  _int_databit
    btfss CCP1CON,0
    incf  SYNCBITS,f
    btfsc CCP1CON,0
    goto  _int_reset
    movfw SYNCBITS
    xorlw 0x09
    btfsc STATUS,Z
    bsf   DSTATE,D_PARSING
    goto  _int_out    
_int_databit
    bcf   STATUS,IRP
    movfw BITNO
    andlw 0x38
    movwf FSR
    bcf   STATUS,C
    rrf   FSR,f
    rrf   FSR,f
    rrf   FSR,w
    addlw 0x78
    movwf FSR
    bcf   STATUS,C
    rlf   INDF,f
    btfss CCP1CON,0
    bsf   INDF,0
    incf  BITNO,f
    movfw BITNO
    xorlw 55
    bnz   _int_out
    bsf   DSTATE,D_PARSED
    goto  _int_out
 
main
    ; setup IO pins
    bsf   STATUS,RP0
    movlw 0x06
    movwf ADCON1  ; all pins to digital
    bcf   STATUS,RP0
    
    bsf   PORTA,4 ; yled
    bsf   PORTA,5 ; gled
    bcf   PORTB,1 ; bzr
    bcf   PORTB,3 ; relay
    bcf   PORTA,0 ; key column 0
    bcf   PORTA,1 ; key column 1
    bcf   PORTA,2 ; key column 2
    bcf   PORTA,3 ; key column 3
    bsf   PORTB,4 ; key row 1
    bsf   PORTB,5 ; key row 2
    bsf   PORTB,6 ; key row 3
    bsf   PORTB,7 ; key row 4
    bsf   STATUS,RP0
    bcf   TRISA,4 ; yled
    bcf   TRISA,5 ; gled
    bcf   TRISB,1 ; bzr
    bcf   TRISB,3 ; relay
    bcf   OPTION_REG,7 ; enable pullups on portb
    bcf   TRISA,0 ; key column 0
    bcf   TRISA,1 ; key column 1
    bcf   TRISA,2 ; key column 2
    bcf   TRISA,3 ; key column 3
    bcf   STATUS,RP0
    
    
    ; setup 125kHz 50% duty on CCP2
    bsf   STATUS,RP0
    movlw 0x03
    movwf PR2
    bcf   TRISC,1
    clrf  STATUS
    movlw 0x02
    movwf CCPR2L
    movlw 0x0c
    movwf CCP2CON
    movlw 0x05
    movwf T2CON
    
    ;prep tmr1 1Mhz
    movlw 0x31 ; prescaler 8, enable timer
    movwf T1CON
    
    ; arm ccp1 in capture mode
    clrf  CCP1CON
    movlw 0x04
    movwf CCP1CON
    bsf   STATUS,RP0
    bsf   PIE1,CCP1IE
    bcf   STATUS,RP0
    
    
    ; setup UART 9600bps
    movlw 0x90
    movwf RCSTA
    bsf   STATUS,RP0
    movlw 50
    movwf SPBRG
    movlw 0x24
    movwf TXSTA
    ; bsf   PIE1,TXIE
    bcf   STATUS,RP0
    
    ; setup keypad interface
    clrf  K_DOWN
    clrf  K_WAIT

    ; enable interrupts
    bsf   INTCON,PEIE
    bsf   INTCON,GIE
    
loop
    ; check UART
    btfss PIR1,RCIF
    goto norx
    movfw RCREG
    movwf TEMP1
    movlw 'y'
    xorwf TEMP1,w
    bz    y_off
    movlw 'Y'
    xorwf TEMP1,w
    bz    y_on
    movlw 'b'
    xorwf TEMP1,w
    bz    b_off
    movlw 'B'
    xorwf TEMP1,w
    bz    b_on
    movlw 'r'
    xorwf TEMP1,w
    bz    r_off
    movlw 'R'
    xorwf TEMP1,w
    bz    r_on
    movlw 'g'
    xorwf TEMP1,w
    bz    g_off
    movlw 'G'
    xorwf TEMP1,w
    bz    g_on
    goto norx
b_off
    bcf PORTB,1
    goto rx_ok
b_on
    bsf PORTB,1
    goto rx_ok
r_off
    bcf PORTB,3
    goto rx_ok
r_on
    bsf PORTB,3
    goto rx_ok
y_off
    bsf PORTA,4
    goto rx_ok
y_on
    bcf PORTA,4
    goto rx_ok
g_off
    bsf PORTA,5
    goto rx_ok
g_on
    bcf PORTA,5
    goto rx_ok
rx_ok
    movlw 'O'
    call  uart_sendbyte
    movlw 'K'
    call  uart_sendbyte
    movlw '\r'
    call  uart_sendbyte
    movlw '\n'
    call  uart_sendbyte
norx
    
    btfss DSTATE,D_PARSED
    goto  nofop
    movlw 'T'
    call  uart_sendbyte
    call  verify_fop
    iorlw 0x00
    bnz   errfop
    movfw TAG1
    call  uart_sendhexbyte
    movfw TAG2
    call  uart_sendhexbyte
    movfw TAG3
    call  uart_sendhexbyte
    movfw TAG4
    call  uart_sendhexbyte
    movfw TAG5
    call  uart_sendhexbyte
    goto  outfop
errfop
    movlw 'e'
    call  uart_sendbyte
    movlw 'r'
    call  uart_sendbyte
    movlw 'r'
    call  uart_sendbyte
outfop
    movlw '\r'
    call  uart_sendbyte
    movlw '\n'
    call  uart_sendbyte
    clrf  BITNO
    clrf  SYNCBITS
    movlw 0x02
    movwf DSTATE
nofop

    call  kbd_handler
    movfw K_DOWN
    bz    nokey
    movlw 'K'
    call  uart_sendbyte
    movfw K_DOWN
    call  uart_sendbyte
    movlw '\r'
    call  uart_sendbyte
    movlw '\n'
    call  uart_sendbyte
    clrf  K_DOWN 
nokey

    goto loop

kbd_handler
    movf  K_DOWN,f
    btfss STATUS,Z
    return
    movf  K_WAIT,f
    bz    kbd_primed
    movfw PORTB
    andlw 0xf0
    xorlw 0xf0
    btfss STATUS,Z
    return
    call  delay1ms
    clrf  K_WAIT
kbd_primed
    btfss PORTB,7
    bsf   K_DOWN,3
    btfss PORTB,6
    bsf   K_DOWN,2
    btfss PORTB,5
    bsf   K_DOWN,1
    btfss PORTB,4
    bsf   K_DOWN,0
    movf  K_DOWN,f
    btfsc STATUS,Z ;; exit if no keys down
    return
    ;; we now know the row determine column by toggling IO
    bsf   PORTA,1
    bsf   PORTA,2
    call  delay1ms
    movfw PORTB
    andlw 0xf0
    xorlw 0xf0
    bz   kbd_iscol23
    bsf   PORTA,3
    call  delay1ms
    movfw PORTB
    andlw 0xf0
    xorlw 0xf0
    bz    kbd_iscol1
    bsf   K_DOWN,4
    goto  kbd_done
kbd_iscol1    
    bsf   K_DOWN,5
    goto  kbd_done
kbd_iscol23
    bsf   PORTA,0
    bcf   PORTA,1
    bsf   PORTA,3
    call  delay1ms
    movfw PORTB
    andlw 0xf0
    xorlw 0xf0
    bz    kbd_iscol2
    bsf   K_DOWN,6
    goto  kbd_done
kbd_iscol2
    bsf   K_DOWN,7
kbd_done
    bcf   PORTA,0
    bcf   PORTA,1
    bcf   PORTA,2
    bcf   PORTA,3    
    bsf   K_WAIT,0
    call  kbd_decode
    movwf K_DOWN
    return

    ;;decode 11-M 21-1 81-2 41 3
    ;;            22-4 82-5 42-6
    ;;            24-7 84-8 44-9
    ;;            28-* 88-0 48-#
kbd_decode
    btfss K_DOWN,7
    goto  kbd_d1
    btfsc K_DOWN,0
    retlw '2'
    btfsc K_DOWN,1
    retlw '5'
    btfsc K_DOWN,2
    retlw '8'
    btfsc K_DOWN,3
    retlw '0'
kbd_d1
    btfss K_DOWN,6
    goto  kbd_d2
    btfsc K_DOWN,0
    retlw '3'
    btfsc K_DOWN,1
    retlw '6'
    btfsc K_DOWN,2
    retlw '9'
    btfsc K_DOWN,3
    retlw '#'
kbd_d2
    btfss K_DOWN,5
    goto  kbd_d3
    btfsc K_DOWN,0
    retlw '1'
    btfsc K_DOWN,1
    retlw '4'
    btfsc K_DOWN,2
    retlw '7'
    btfsc K_DOWN,3
    retlw '*'
kbd_d3
    retlw 'M'
    retlw 0
    
delay1ms
    movlw 6
_d1ms
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    addlw 1
    bnz   _d1ms
    return

uart_sendbyte
    btfss PIR1,TXIF
    goto  uart_sendbyte
    movwf TXREG
    return

uart_sendhexbyte
    movwf TEMP1
    swapf TEMP1,w
    call  nib2asc
    call  uart_sendbyte
    movfw TEMP1
    call  nib2asc
    call  uart_sendbyte
    return

verify_fop
    ;; gather data bits from the stream
    movfw 0x78
    andlw 0xf0
    movwf TAG1
    movfw 0x78
    movwf TEMP1
    rlf   TEMP1,w
    andlw 0x0e
    btfsc 0x79,7
    iorlw 0x01
    iorwf TAG1,f
    
    movfw 0x79
    movwf TEMP1
    rlf   TEMP1,f
    rlf   TEMP1,w
    andlw 0xf0
    movwf TAG2
    swapf 0x7a,w
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x07
    iorwf TAG2,f
    btfsc 0x79,0
    bsf   TAG2,3

    swapf 0x7a,w
    andlw 0xf0
    movwf TAG3
    movfw 0x7b
    movwf TEMP1
    rrf   TEMP1,f
    rrf   TEMP1,f
    rrf   TEMP1,w
    andlw 0x0f
    iorwf TAG3,f
    
    movfw 0x7c
    movwf TEMP1
    rrf   TEMP1,f
    rrf   TEMP1,w
    andlw 0x30
    movwf TAG4
    btfsc 0x7b,1
    bsf   TAG4,7
    btfsc 0x7b,0
    bsf   TAG4,6
    
    movfw 0x7c
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x0f
    iorwf TAG4,f
    
    movfw 0x7d
    andlw 0xf0
    movwf TAG5
    rlf   0x7d,w
    andlw 0x0e
    iorwf TAG5,f
    btfsc 0x7e,6
    bsf   TAG5,0

    ;; calculate parity bits on first two nibbles
    movfw TAG1
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x55
    xorwf TEMP1,f ;; xor bits 76 54 32 and 10, result in 6420
    rrf   TEMP1,w ;; bit 6 and 2 to position 5 and 1
    rlf   TEMP1,f ;; bits 4 and 0 to position 5 and 1
    xorwf TEMP1,w ;; calculate parity at 5 and 1, results in those
    ;; factor in the parity bits from bitstream
    btfsc 0x78,3
    xorlw 0x20 ; bit 5
    btfsc 0x79,6
    xorlw 0x02 ; bit 1
    ;; they should be zeroes now per even parity
    andlw 0x22
    btfss STATUS,Z
    retlw 1
    
    movfw TAG2
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x55
    xorwf TEMP1,f ;; xor bits 76 54 32 and 10, result in 6420
    rrf   TEMP1,w ;; bit 6 and 2 to position 5 and 1
    rlf   TEMP1,f ;; bits 4 and 0 to position 5 and 1
    xorwf TEMP1,w ;; calculate parity at 5 and 1, results in those
    ;; factor in the parity bits from bitstream
    btfsc 0x79,1
    xorlw 0x20 ; bit 5
    btfsc 0x7a,4
    xorlw 0x02 ; bit 1
    ;; they should be zeroes now per even parity
    andlw 0x22
    btfss STATUS,Z
    retlw 1
    
    movfw TAG3
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x55
    xorwf TEMP1,f ;; xor bits 76 54 32 and 10, result in 6420
    rrf   TEMP1,w ;; bit 6 and 2 to position 5 and 1
    rlf   TEMP1,f ;; bits 4 and 0 to position 5 and 1
    xorwf TEMP1,w ;; calculate parity at 5 and 1, results in those
    ;; factor in the parity bits from bitstream
    btfsc 0x7b,7
    xorlw 0x20 ; bit 5
    btfsc 0x7b,2
    xorlw 0x02 ; bit 1
    ;; they should be zeroes now per even parity
    andlw 0x22
    btfss STATUS,Z
    retlw 1

    movfw TAG4
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x55
    xorwf TEMP1,f ;; xor bits 76 54 32 and 10, result in 6420
    rrf   TEMP1,w ;; bit 6 and 2 to position 5 and 1
    rlf   TEMP1,f ;; bits 4 and 0 to position 5 and 1
    xorwf TEMP1,w ;; calculate parity at 5 and 1, results in those
    ;; factor in the parity bits from bitstream
    btfsc 0x7c,5
    xorlw 0x20 ; bit 5
    btfsc 0x7c,0
    xorlw 0x02 ; bit 1
    ;; they should be zeroes now per even parity
    andlw 0x22
    btfss STATUS,Z
    retlw 1

    movfw TAG5
    movwf TEMP1
    rrf   TEMP1,w
    andlw 0x55
    xorwf TEMP1,f ;; xor bits 76 54 32 and 10, result in 6420
    rrf   TEMP1,w ;; bit 6 and 2 to position 5 and 1
    rlf   TEMP1,f ;; bits 4 and 0 to position 5 and 1
    xorwf TEMP1,w ;; calculate parity at 5 and 1, results in those
    ;; factor in the parity bits from bitstream
    btfsc 0x7d,3
    xorlw 0x20 ; bit 5
    btfsc 0x7e,5
    xorlw 0x02 ; bit 1
    ;; they should be zeroes now per even parity
    andlw 0x22
    btfss STATUS,Z
    retlw 1

    ;; now calculate 'column parity'
    movfw TAG1
    xorwf TAG2,w
    xorwf TAG3,w
    xorwf TAG4,w
    xorwf TAG5,w
    movwf TEMP1
    swapf TEMP1,w
    xorwf TEMP1,w
    ;; add parity bits
    btfsc 0x7e,4
    xorlw 0x88
    btfsc 0x7e,3
    xorlw 0x44
    btfsc 0x7e,2
    xorlw 0x22
    btfsc 0x7e,1
    xorlw 0x11
    ;; if parity is ok we ended up with 0x00
    btfss STATUS,Z
    retlw 1
        
    ;; finally stop bit must be 0
    btfsc 0x7e,0
    retlw 1
    
    retlw 0
        
    org   0x600
nib2asc
    clrf  PCLATH
    bsf   PCLATH,2
    bsf   PCLATH,1
    andlw 0x0f
    addwf PCL,f
    retlw '0'
    retlw '1'
    retlw '2'
    retlw '3'
    retlw '4'
    retlw '5'
    retlw '6'
    retlw '7'
    retlw '8'
    retlw '9'
    retlw 'A'
    retlw 'B'
    retlw 'C'
    retlw 'D'
    retlw 'E'
    retlw 'F'
        
    end