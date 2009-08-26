        include         "processor_def.inc"
	include         "common.inc"
	include         "constants.inc"
	include         "memory.inc"
	include		"serial.inc" ;debug
	
	GLOBAL  maxm_init
	GLOBAL	maxm_all_off
	GLOBAL	maxm_full_white
	GLOBAL	maxm_full_blue
	GLOBAL	maxm_full_green
	GLOBAL	maxm_mood_light
	GLOBAL	maxm_pulse_red
	GLOBAL	maxm_fade_blue
	GLOBAL	maxm_fade_white
	GLOBAL	maxm_fade_to_rgb

maxm	code
check_start_maxm:	
	include		"i2c.inc"

;;; MAXM_GETRGB is broken. It hangs the device after using it a couple of times,which means I've got it wrong. instead I'm returning an arbitrary value
MAXM_GETRGB	MACRO
	movlw	0x00
	movwf	red_mood
	movlw	0xFF
	movwf	green_mood
	movlw	0x80
	movwf	blue_mood
	ENDM

MAXM_GETRGB_BUSTED	MACRO
	lcall	maxm_i2c_start
	movlw	0x09 << 1 	; slave adress + write
	call	write_I2C
	movlw	'g'		; "get"
	call	write_I2C
	call	maxm_i2c_start
	movlw	0x09 << 1 | 1 	; save address + read
	call	write_I2C
	call	read_I2C
	movwf	red_mood
	call	ack
	call	read_I2C
	movwf	green_mood
	call	ack
	call	read_I2C
	movwf	blue_mood
	call	nack
	call	maxm_i2c_stop
	ENDM
	
MAXM_STOP_SCRIPTS	MACRO
        lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'o'	; "all off" command
	call    write_I2C
	call	maxm_i2c_stop
	ENDM

MAXM_PLAY_SCRIPT	MACRO	SCPTNUM, LN
	lcall	maxm_i2c_start
	movlw   0x09 << 1	; slave address + write
	call    write_I2C
	movlw   'p'		; "play script" command
	call    write_I2C
	movlw	SCPTNUM		; script number
	call    write_I2C
	movlw	0		; loop it forever
	call	write_I2C
	movlw	LN		; play starting at beginning
	call	write_I2C
	call	maxm_i2c_stop
	ENDM

MAXM_SETRGB	MACRO	R,G,B
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'n'	; "set to color right now" command
	call    write_I2C
	movlw   R	; red
	call    write_I2C
	movlw   G	; green
	call    write_I2C
	movlw   B	; blue
	call    write_I2C
	call	maxm_i2c_stop
	ENDM
	
	
MAXM_FADERGB	MACRO	R,G,B
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'c'	; "fade to color" command
	call    write_I2C
	movlw   R	; red
	call    write_I2C
	movlw   G	; green
	call    write_I2C
	movlw   B	; blue
	call    write_I2C
	call	maxm_i2c_stop
	ENDM

MAXM_FADESPEED	MACRO	SPEED
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'f'	; "fade speed" command
	call    write_I2C
	movlw	SPEED		; 1 slowest; 255 fastest
	call	write_I2C
	call	maxm_i2c_stop
	ENDM

MAXM_FADERANDOM	MACRO
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'C'	; "fade to random RGB" command
	call    write_I2C
	movlw	0xFF		; R "distance"
	call	write_I2C	
	movlw	0xFF		; G "distance"
	call	write_I2C	
	movlw	0xFF		; B "distance"
	call	write_I2C
	call	maxm_i2c_stop
	ENDM

MAXM_TIMEADJUST	MACRO TIME
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   't'	; "time adjust" command
	call    write_I2C
	movlw	TIME
	call	write_I2C	
	call	maxm_i2c_stop
	ENDM
MAXM_WRITE_PROG	MACRO PN, LN, T, CMD, A1, A2, A3
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'W'	; "write program"
	call    write_I2C
	movlw	PN
	call	write_I2C	
	movlw	LN
	call	write_I2C	
	movlw	T
	call	write_I2C	
	movlw	CMD
	call	write_I2C	
	movlw	A1
	call	write_I2C	
	movlw	A2
	call	write_I2C	
	movlw	A3
	call	write_I2C	
	call	maxm_i2c_stop
	call	delay_13ms	; a bug in the maxm requires ~20mS delay
	call	delay_13ms
	ENDM
MAXM_SET_PROGLEN	MACRO PN, LN, RPT
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'L'	; "write program length"
	call    write_I2C
	movlw	PN
	call	write_I2C	
	movlw	LN
	call	write_I2C	
	movlw	RPT
	call	write_I2C	
	call	maxm_i2c_stop
	call	delay_13ms	; dunno if this has the same bug, but to be 
	call	delay_13ms	;  safe, thought I'd put these in here...
	ENDM

	
delay_13ms:
	clrf	maxm_temp
	clrf	maxm_temp2
	incfsz	maxm_temp, F
	goto	$-1
	incfsz	maxm_temp2, F
	goto	$-3
	return

maxm_init:
#if 0
	;; only have to do this once for each MaxM module to program it
	;; initially.
	
	;; write the program to maxm
	MAXM_WRITE_PROG 0,0,1,'f',10,0,0
	MAXM_WRITE_PROG 0,1,100,'c',0xff,0xff,0xff
	MAXM_WRITE_PROG 0,2,50,'c',0xff,0,0
	MAXM_WRITE_PROG 0,3,50,'c',0,0xff,0
	MAXM_WRITE_PROG 0,4,50,'c',0,0,0xff
	MAXM_WRITE_PROG 0,5,50,'c',0,0,0
	MAXM_WRITE_PROG 0,6,1,'j',-5,0,0
	MAXM_WRITE_PROG 0,7,1,'f',1,0,0
	
	MAXM_WRITE_PROG 0,8,0xff,'C',255,255,255	    ; start @ random RGB
	MAXM_WRITE_PROG 0,9,0xff,'H',0x80,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,10,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,11,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,12,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,13,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,14,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,15,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,16,0xff,'H',0x00,0x80,0
	MAXM_WRITE_PROG 0,17,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,18,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,19,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,20,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,21,0xff,'H',0x19,0,0         ; cycle thru some hues
	MAXM_WRITE_PROG 0,22,0xff,'H',0x19,0,0         ; cycle thru some hues

	MAXM_WRITE_PROG 0,23,0xff,'C',0x32,0x32,0x32  ; ~20% change
	MAXM_WRITE_PROG 0,24,1,'j',-13,0,0          ; jump back, do it again
	MAXM_SET_PROGLEN 0,25,0
#endif
	
	MAXM_FADESPEED	15
	;; fall through to maxm_all_off
	
maxm_all_off:
#if 0
	;; debug: perform an I2C bus reset, just in case the maxm is now hung.
        lcall   maxm_i2c_start
	movlw   0x00
	call	write_I2C
	movlw   0xFF
	call	write_I2C
        lcall   maxm_i2c_start
	call	maxm_i2c_stop
#endif
	
	MAXM_STOP_SCRIPTS
	MAXM_SETRGB 0x00, 0x00, 0x00
	return

maxm_full_white:
	MAXM_STOP_SCRIPTS
	MAXM_FADESPEED 15
	MAXM_FADERGB 0xFF, 0xFF, 0xFF
	return

maxm_full_blue:
	MAXM_STOP_SCRIPTS
	MAXM_FADESPEED 15
	MAXM_FADERGB 0x00, 0x00, 0xFF
	return

maxm_full_green:
	MAXM_STOP_SCRIPTS
	MAXM_FADESPEED 15
	MAXM_FADERGB 0x00, 0xFF, 0x00
	return

maxm_mood_light:
	MAXM_FADESPEED 0xFF 	; fastest possible
	MAXM_FADERANDOM
	call	delay_13ms
	MAXM_GETRGB
	
	MAXM_FADESPEED 0x01	; slowest possible
	clrf	mood_delay
	return
	
maxm_pulse_red:
	MAXM_PLAY_SCRIPT d'3', 0
	MAXM_FADESPEED	25
	return

;;; set to blue brightness specified in W (0-255)
maxm_fade_blue:
	movwf	maxm_temp
	MAXM_FADESPEED	15
	MAXM_STOP_SCRIPTS
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'c'	; "fade to color" command
	call    write_I2C
	movlw   0x00	; red
	call    write_I2C
	movlw   0x00	; green
	call    write_I2C
	movfw	maxm_temp	; blue
	call    write_I2C
	call	maxm_i2c_stop
	return

maxm_fade_white:
	movwf	maxm_temp
	MAXM_FADESPEED	15
	MAXM_STOP_SCRIPTS
	lcall	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'c'	; "fade to color" command
	call    write_I2C
	movfw	maxm_temp	; red
	call    write_I2C
	movfw	maxm_temp	; green
	call    write_I2C
	movfw	maxm_temp	; blue
	call    write_I2C
	call	maxm_i2c_stop
	return

maxm_fade_to_rgb:
	call	maxm_i2c_start
	movlw   0x09 << 1 ; slave address + write
	call    write_I2C
	movlw   'c'	; "fade to color" command
	call    write_I2C
	movfw	red_mood
	call    write_I2C
	movfw	green_mood
	call    write_I2C
	movfw	blue_mood
	call    write_I2C
	call	maxm_i2c_stop
	return

	
	
maxm_i2c_start:
	banksel	0
	I2C_START
	return

maxm_i2c_stop:
	banksel	0
	I2C_STOP
	return
	
check_end_maxm:	
	end
	