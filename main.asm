	include "processor_def.inc"

	include "spi.inc"
	include "sd_spi.inc"
	include "constants.inc"
	include "memory.inc"
	include "common.inc"
	include "mood_lights.inc"
	include "ds1307-i2c.inc"
	include "music.inc"
	include "serial.inc"
	include "piceeprom.inc"
	include "events.inc"
	include	"bootloader.inc"
	include	"button.inc"
	include "maxm.inc"
	
	GLOBAL	normal_startup
	
	__CONFIG ( _CP_OFF & _DEBUG_OFF & _WRT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC )

_ResetVector	set	0x00
_InitVector	set	0x04

;;; ************************************************************************
;;;   **  all variables defined in memory.inc manually  **
;;; ************************************************************************
.string	code
msg_firmware
	da	"Firmware v0x"
	dw	0x0000
msg_crlf
	da	"\r\n"
	dw	0x0000
msg_timeis
	da	"Time is: "
	dw	0x0000
msg_initevent
	da	"\r\nInitializing event table\r\n"
	dw	0x0000
msg_alarm
	da	" alarm: "
	dw	0x0000
	
main	code

	CONSTANT	_block_start = $
	
	org	_ResetVector
	lgoto	bootloader

	org	_InitVector
	nop			; fall through to Interrupt label.

	org 0x05
	
Interrupt:
;;;  standard interrupt setup: save everything!
	movwf   save_w
	swapf   STATUS, W
	movwf   save_status
	bcf	STATUS, RP1
	bcf     STATUS, RP0
	movf    PCLATH, W
	movwf   save_pclath
	clrf    PCLATH
	movfw	FSR
	movwf	save_fsr

;;;  start of interrupt functionality
	pagesel	handle_t2
	btfsc	PIR1, TMR2IF	; is in bank 0
	goto	handle_t2
	
done_t2:
	banksel	0
	pagesel	handle_t1
	btfsc	PIR1, TMR1IF	; is in bank 0
	goto	handle_t1	; must be in the same page as this call...

done_t1:
	banksel	0
	pagesel	handle_t0
	btfsc	INTCON, T0IF	; is in bank 0
	goto	handle_t0	; must be in the same page as this call...

done_int:
;;;  clean up everything we saved...
	movfw	save_fsr
	movwf	FSR
	movf    save_pclath, W
	movwf   PCLATH
	swapf   save_status, W
	movwf   STATUS
	swapf   save_w, F
	swapf   save_w, W
	retfie

handle_t2:
	bcf	PIR1, TMR2IF
	goto	done_t2
	
handle_t1:
	bcf	PIR1, TMR1IF
	bsf	MOOD_LIGHT_NEEDS_HANDLING ; can't touch the I2C bus here

	incfsz	rtc_timer, F
	goto	done_t1
 	bsf	need_reread_clock, 0 ; set need_reread_clock to non-zero
	goto	done_t1
	
handle_t0:
	bcf	INTCON, T0IF

;;; With an 8MHz xtal, we needed to add 6 cycles to TMR0 to keep it at an
;;; honest 8kHz sampling rate. Since setting TMR0 skips 2 cycles, we added
;;; only 4.
;;; Xtal subsequently upgraded to 20MHz, which meant a preload of 0x64 to
;;; hit 16kHz (16025.64kHz to be exact). Preload of 0x60 is exactly 15625Hz,
;;; which might be more suitable.
;;; ... But there's too much going on, and the pic couldn't keep up with
;;; both the PWM and the audio code (PWM takes too long to execute). Dropped
;;; back to 8kHz (8012.82Hz), which works fine. (Made this change solely by
;;; changing the prescaler in the TMR0 setup code.)
;;; ... And as a test, trying out something faster: can we play ~10kHz and
;;; improve audio quality a bit, but stay under the threshold for processor
;;; duress? Preload of 131 (0x83) is precisely 10kHz @ prescaler of 1:4, as
;;; is 1:2 @ preload of 0x06. Don't know if one of those is intrinsically
;;; better than the other. Starting with 1:4 b/c that's already the
;;; prescaler we were using before...
;;; 
;;; NOTE: Any change of the TMR0 speed affects the alarm timer (light
;;; brightening speed) in mood_lights.asm!

  	movlw   0x83 - 2
	addwf	TMR0, F

	lcall	play_another_sample
	
done_t0:
	;; used to do PWM maint here, but now that we're using a MaxM...
	lgoto	done_int
	

	org	0x100
;;; normal_startup
;;;
;;;   entry point from the bootloader. MUST be 0x100 (matching
;;; 	bootloader/bootloader.asm's definition).
	
normal_startup:
        banksel ADCON0
	movlw   b'01100000' ; AN0 is analog, others digital. Powered off.
	movwf   ADCON0
	banksel ADCON1
	movlw   b'11001110'
	movwf   ADCON1
	
        banksel PORTA
	bcf     AUDIO_ENABLE
	bsf     BLUE_LED
	bsf     RED_LED
	bsf     GREEN_LED
	
	banksel TRISA
	movlw   TRISA_DATA
	movwf   TRISA
	banksel TRISB
	movlw   TRISB_DATA
	movwf   TRISB
	BANKSEL TRISC
	movlw   TRISC_DATA
	movwf   TRISC
	BANKSEL TRISD
	movlw   TRISD_DATA
	movwf   TRISD
	BANKSEL TRISE
	movlw   TRISE_DATA
	movwf   TRISE
	banksel	0
	
	lcall	init_memory

	;; initialize PWMs
	lcall	maxm_init

;;; set up bit-banging spi interface (for D/A chip) and built-in (for SD card)
;;; ... the SPI initialization done by the bootloader is sufficient.
;;; 	lcall	init_spi

	banksel	PORTA
	bcf	RED_LED		; status update...

;;; The serial initialization done by the bootloader is sufficient.
;;; 	fcall	init_serial

	;; Display the firmware version on the serial port. We'll dig the
	;; actual reported version # out of program memory, where it's being
	;; stored and updated by the bootloader.
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_firmware
	movlw	0x1e
	movwf	arg1
	movlw	0x00
	movwf	arg2
	lcall	fpm_read
	banksel	EEDATA
	movfw	EEDATA
	banksel	0
	lcall	putch_hex_usart
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_crlf

	fcall	mmc_init

	call	clear_transient_table

	banksel	PORTA
	bcf	BLUE_LED	; status update...
	
	;; Move SPI bus to super-fast speed (osc/4 instead of osc/64)
	banksel	SSPCON
	bcf	SSPCON, SSPM1
	banksel	0

;;; ; give the SD card a few seconds to start up. Note that the page must be
;;; ; properly set, since we use goto...
	banksel sleep_ctr
	pagesel bootloader_delay
bootloader_delay:
	clrf    sleep_ctr
	clrf    sleep_ctr+1
	movlw   0x02
	movwf   sleep_ctr+2
	decfsz  sleep_ctr, F
	goto    $-1	    
	decfsz  sleep_ctr+1, F
	goto    $-3
	decfsz  sleep_ctr+2, F
	goto    $-5

;;; set up tmr0
	BANKSEL	OPTION_REG
 	movlw	b'10000001'	; disable pull-ups<7>, prescaler 1:4<3:0>
	movwf	OPTION_REG

;;; set up tmr1
	banksel	T1CON
	bsf	T1CON, T1CKPS1
	bsf	T1CON, T1CKPS0
	bcf	T1CON, T1OSCEN
	bsf	T1CON, T1SYNC
	bcf	T1CON, TMR1CS
	clrf	TMR1H
	clrf	TMR1L

;;; set up tmr2
	banksel	T2CON
	movfw	T2CON
	iorlw	0x78		; postscaler 1:16
	movwf	T2CON
	bsf	T2CON, T2CKPS1	; prescaler 1:16
	bcf	T2CON, T2CKPS0
	banksel	PR2
	movlw	0xFF		; should be redundant; init'd to 0xFF anyway
	movwf	PR2

	banksel	0

;;; read the time to start up
	lcall	RTC_brst_rd
	bcf	BLUE_LED

	;; spit out the current time on startup (for easier debugging)
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_timeis
	
	movfw	time_mon
	lcall	putch_BCD_usart
	movlw	'/'
	lcall	putch_usart
	movfw	time_days
	lcall	putch_BCD_usart
	movlw	'/'
	lcall	putch_usart
	movfw	time_yrs
	lcall	putch_BCD_usart
	movlw	' '
	lcall	putch_usart
	movfw	time_hrs
	lcall	putch_BCD_usart
	movlw	':'
	lcall	putch_usart
	movfw	time_mins
	lcall	putch_BCD_usart
	movlw	':'
	lcall	putch_usart
	movfw	time_secs
	lcall	putch_BCD_usart
	
;;; force the lights to initialize themselves internally by telling the light
;;; subsystem that it was on, but we want it off now.
	movlw	LIGHTS_ON
 	movwf	cur_lamp_mode
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode

;;; check to see if the eeprom is initialized. If not, then do it.
	movlw	EEPROM_INIT_FLAG
	fcall	eep_read	; must be an fcall, so that the goto works
	xorlw	EEPROM_INIT_MAGIC
	skpnz
	goto	dont_have_to_init

	PUTCH_CSTR_INLINE putch_cstr_worker, msg_initevent
	
	;; have to initialize the eeprom. Clear all events...
	lcall	clear_all_events
	;; ... and set the initialized flag.
	movlw	EEPROM_INIT_FLAG
	movwf	arg2
	movlw	EEPROM_INIT_MAGIC
	lcall	eep_write

dont_have_to_init:
;;; preload the alarm settings from the RTC, checking validity
	fcall	RTC_RdAlarm
	movfw	alarm_h		; alarm > 23 hours (BCD)? bad.
	sublw	0x23
	skpwle
	goto	alarm_bad

	movfw	alarm_m		; alarm > 59 minutes (BCD)? bad.
	sublw	0x59
	skpwle
	goto	alarm_bad

	movfw	alarm_h		; check low digit for BCD invalid values
	andlw	0x0f		; if hours digit > 9, bad.
	sublw	0x09
	skpwle
	goto	alarm_bad

	movfw	alarm_m		; same: if minutes digit > 9, bad.
	andlw	0x0f
	sublw	0x09
	skpwle
	goto	alarm_bad

	;; alarm_light_type must have only one bit set, and it must be in the low three.
	;; if invalid, set to blue.
	movfw	alarm_light_type
	andlw	0xF8		; mask of all-but-three-good-bits
	addlw	0x00
	skpz
	goto	alarm_bad
	
	movlw	0x00
	btfsc	ALARM_LIGHT_BLUE
	addlw	0x01
	btfsc	ALARM_LIGHT_WHITE
	addlw	0x01
	btfsc	ALARM_LIGHT_DISABLED
	addlw	0x01

	xorlw	0x01
	skpnz			; either 0 bits are set, or more than 1. Anyway, bad...
	goto	continue_after_alarm_init
	
alarm_bad:	
	movlw	0x06		; set alarm to 6:30 AM if it's bad
	movwf	alarm_h		; (remember, it's BCD)
	movlw	0x30
	movwf	alarm_m
	movlw	0x01		; set alarm back to 'blue'
	movwf	alarm_light_type
	
continue_after_alarm_init:
;;; debugging: spit out the alarm time too
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_alarm
	movfw	alarm_h
	lcall	putch_BCD_usart
	movlw	':'
	lcall	putch_usart
	movfw	alarm_m
	fcall	putch_BCD_usart

;;; debugging: is the alarm switch on or off?
	banksel	SWITCH_PORT
	movlw	' '
	lcall	putch_usart
	movlw	'0'
	btfss	ALARM_ENABLE	; enabled low: skip-if-off
	movlw	'1'
	lcall	putch_usart

	PUTCH_CSTR_INLINE putch_cstr_worker, msg_crlf
	
	banksel	0
	fcall	init_media_queue

	;; Ready to run: handle interrupt enabling. They're all configured
	;; appropriately, just need to turn on the plethora of enable bits
	banksel	INTCON
	clrf	INTCON

	bcf	PIR1, TMR2IF	; enable tmr2 overflows
	bcf	PIR1, TMR1IF	; enable tmr1 overflows
	banksel	PIE1
;;;  	bsf	PIE1, TMR2IE	; enable TMR2's interrupt
  	bsf	PIE1, TMR1IE	; enable TMR1's interrupt
	banksel	0
;;; 	bsf	T2CON, TMR2ON	; turn TMR2 on
	bsf	T1CON, TMR1ON	; turn TMR1 on
   	bsf     INTCON, T0IE	; enable TMR0's interrupt
   	bsf	INTCON, GIE	; and globally turn on all enabled interrupts
	bsf	INTCON, PEIE	; and also for all unmasked peripheral ints

	movlw	0xff		; preload the timer so that it will go off
	movwf	rtc_timer	; right away.

	banksel	0
	
loop_forever:
	lcall	buffer_more_music
	
	;; on ultra-long button holds, handle that before 'normal' buttons.
	pagesel	ultra_long_buttonpress
	btfsc	BUTTON_HELD_ULTRA_LONG
	call	ultra_long_buttonpress
	bcf	BUTTON_HELD_ULTRA_LONG
	fcall	handle_button

;;; check to see if we're in the alarm or alarming states with the alarm enable
;;; turned off. If so, disable the alarm state we're in (just like a button press)
;;; by calling button_cancel_alarm.

	btfss	ALARM_ENABLE	; alarm_enable is active-low. So is it 'off'?
	goto	nothing_to_see_here
	;; alarm is not enabled. Are we in an alarming mode? If so, end it
	movlw	LIGHTS_ALARMING
	xorwf	cur_lamp_mode, W
	skpnz
	goto	disable_it
	movlw	LIGHTS_ALARM
	xorwf	cur_lamp_mode, W
	skpz
	goto	nothing_to_see_here
disable_it:
	fcall	button_cancel_alarm

nothing_to_see_here:	
	;; reload the clock from the device if necessary - but not if playing
	;; any sound. Don't want I2C traffic interrupting playback. Also don't
	;; update the clock at all if we're currently setting date/time; we'll
	;; be using the time_* values as temporary storage while doing that...

	movfw	set_time_mode	; if either is set, skip setting of clock
	iorwf	set_alarm_mode, W
	skpz
	goto	skip_clock

	;; If any of the music_control bits are set, we don't do anything
	;; with the clock. This also means we won't accidentally trip off the
	;; alarm timer while we're playing music (or something).
	movfw	music_control	; DOES update Z
	skpnz
	call	handle_clock
skip_clock:
	
	;; Check the various music control flags. Only this loop is allowed
	;; to diddle with the SD card, so anything that might touch it winds
	;; up setting a status flag and deferring the work to here.

	;; same true of anything that needs to talk with the PWM daughterboard
	btfss	MOOD_LIGHT_NEEDS_STEPPING
	goto	end_moodlights
	bcf	MOOD_LIGHT_NEEDS_STEPPING
	
	btfss	RED_MOOD_DIR
	goto	red_mood_down
red_mood_up:
	movlw	0x02
	addwf	red_mood, F
	skpnc
	bcf	RED_MOOD_DIR
	skpnc
	movlw	0xFF
	skpnc
	movwf	red_mood
	goto	blue
red_mood_down:
	movlw	0x00-0x02
	addwf	red_mood, F
	skpc
	bsf	RED_MOOD_DIR
	skpc
	clrf	red_mood

blue:
	btfss	BLUE_MOOD_DIR
	goto	blue_mood_down
blue_mood_up:
	movlw	0x05
	addwf	blue_mood, F
	skpnc
	bcf	BLUE_MOOD_DIR
	skpnc
	movlw	0xFF
	skpnc
	movwf	blue_mood
	goto	green
blue_mood_down:
	movlw	0x00-0x05
	addwf	blue_mood, F
	skpc
	bsf	BLUE_MOOD_DIR
	skpc
	clrf	blue_mood
	
green:
	btfss	GREEN_MOOD_DIR
	goto	green_mood_down
green_mood_up:
	movlw	0x03
	addwf	green_mood, F
	skpnc
	bcf	GREEN_MOOD_DIR
	skpnc
	movlw	0xFF
	skpnc
	movwf	green_mood
	goto	end_green
green_mood_down:
	movlw	0x00-0x03
	addwf	green_mood, F
	skpc
	bsf	GREEN_MOOD_DIR
	skpc
	clrf	green_mood
	
end_green:
	;; if all three pwms are under 50%, make 'em all move upwards. This
	;; should prevent us from hanging around down near black...
	movfw	red_mood
	sublw	0x80
	skpwle
	goto	set_mood_lights
	movfw	blue_mood
	sublw	0x80
	skpwle
	goto	set_mood_lights
	movfw	green_mood
	sublw	0x80
	skpwle
	goto	set_mood_lights

	bsf	RED_MOOD_DIR
	bsf	BLUE_MOOD_DIR
	bsf	GREEN_MOOD_DIR

set_mood_lights
	;; finally, set the pwms appropriately
	fcall	maxm_fade_to_rgb
	
end_moodlights:
	pagesel	mood_handler
	btfsc	MOOD_LIGHT_NEEDS_HANDLING
	call	mood_handler
	pagesel	pulsation_handler
	btfsc	MOOD_LIGHT_NEEDS_HANDLING
	call 	pulsation_handler
	pagesel	$
	bcf	MOOD_LIGHT_NEEDS_HANDLING
	
	;; STOP_MUSIC_NOW means we need to call stop_playing. We must check
	;; this flag before all others, because it might be set in addition
	;; to one of the 'start' conditions (below) and we have to call
	;; stop_playing to re-initialize the SD card first.
	btfss	STOP_MUSIC_NOW
	goto	not_stopmusic
	fcall	stop_playing
	bcf	STOP_MUSIC_NOW
not_stopmusic:
	
	;; NEED_STARTPLAYING means we need to start playing music at the
	;; currently selected block start/stop limits.
	btfss	NEED_STARTPLAYING
	goto	not_startplaying
	fcall	start_playing
	bcf	NEED_STARTPLAYING
not_startplaying:	

	;; NEED_START_ALARM means we need to go into alarm-light mode. The
	;; light should already be on; just start the music for the alert
	;; event.
	btfss	NEED_START_ALARM
	goto	not_startalarm
        fcall   start_alarm_event
	bcf	NEED_START_ALARM
not_startalarm:	

	;; NEED_START_ALERT means that we need to start playing the audio
	;; for an alert. The light is already in the right mode
	;; (LIGHT_ALERTING).	
	btfss	NEED_START_ALERT
	goto	not_startalert
	fcall	start_playing_alert_event
	bcf	NEED_START_ALERT
not_startalert:

	;; NEED_START_TIMEQUEUE means that we need to start playing the
	;; audio events listed in the time queue (go to LIGHTS_SPEAKING).
	btfss	NEED_START_TIMEQUEUE
	goto	not_timequeue
	fcall	start_playing_time_queue
	bcf	NEED_START_TIMEQUEUE
not_timequeue:
	
	;; Done all that: check the serial port last.
	pagesel	loop_forever
	btfsc	MUSIC_PLAYING	; can't pause for serial if we're playing music
	goto	loop_forever
 	fcall	handle_serial	; destroys page bits, so must use fcall
	banksel	0		; handle_serial also destroys banksel
	goto	loop_forever

;;;
;;; handle_clock
;;; 
handle_clock:
	;; somewhere around once a minute (not less frequently) we want to check
	;; the time for alarm events. This timer loop is based on the 9.54Hz INT1
	;; timer. It's a low priority - if we run long, no problem. Just have to be
	;; sure that the ring buffer has time to fill up.
	movfw	need_reread_clock
	skpnz
	return

	clrf	need_reread_clock

	;; Yes, tmr2 is handling times. But we also need to keep the date
	;; correct, which is easier (leap years, all that jazz) in the RTC...
	;; FIXME: build the complex date code and ditch this call
 	fcall	RTC_brst_rd

	;; If it's midnight, clear the daily event-did-fire timers.
	movfw	time_hrs
	addlw	0x00
	skpz
	goto	not_midnight
	movfw	time_mins
	addlw	0x00
	skpnz
	call	clear_transient_table

	
not_midnight:	
	;; No longer checking alarm here; that's in the tmr2 code. But events
	;; are more persnickety - slow RTC read, slow EEPROM reads, slow
	;; access to MMC card - so we'll do those here.
#if 1
	;; FIXME: re-enabled while debugging TMR2 interrupt frequency problem
	movfw	desired_lamp_mode
	xorlw	LIGHTS_ALARM
	skpnz
	return			; alarming? then done checking for events.
	movfw	desired_lamp_mode
	xorlw	LIGHTS_ALARMING
	skpnz
	return			; same thing: if already alarming, then done

	;; check the current time and see if we need to trigger an alarm state.
	;; but only if the alarm is enabled (by hardware switch).
	btfsc	ALARM_ENABLE	; alarm enabled if this is *clear*.
	goto	check_events	;alarm disabled, so skip alarm check
	
	movfw	time_hrs
	xorwf	alarm_h, W
	skpz
	goto	check_events	;no alarm, so look for events
	movfw	time_mins
	xorwf	alarm_m, W
	skpz
	goto	check_events	;no alarm, so look for events

	movlw	'$'		;debug
	fcall	putch_usart	;debug
	
	;; an alarm is ready to go! Set the lights into the alarming mode.
	movlw	LIGHTS_ALARM
	movwf	desired_lamp_mode
	return			;set alarm! don't check events
#endif

check_events:
	;; If we're already in an alerting state, we're done processing;
	;; let the current mode play out.
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SPEAKING
	skpnz
	return
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETTIME
	skpnz
	return
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETALARM
	skpnz
	return
	movfw	desired_lamp_mode
	xorlw	LIGHTS_ALERTING
	skpnz
	return
	movfw	desired_lamp_mode
	xorlw	LIGHTS_ALERT
	skpnz
	return

	;; See if there are any events ready to fire.
	fcall	is_event_available
	xorlw	0x01
	skpz
	return

	;; an event is available. But only notify of it if it's >= 8 AM.
	;; Seriously, nobody wants to be bugged before 8 AM, do they?
	movfw	time_hrs
	sublw	0x07
	skpwgt
	return

	;; an event is ready to play. Enter the alert mode, which will pulsate
	;; the light until someone hits the button.
	movlw	LIGHTS_ALERT
	movwf	desired_lamp_mode

	return

clear_transient_table:	
	;; clear 0x1a0 - 0x1ef, which hold "event did fire" information for
	;; transient events that recur (i.e. can fire more than once).
	movlw	0xa0
	movwf	FSR
	bankisel	0x1a0
clear_next:	
	clrf	INDF
	incf	FSR, F
	movfw	FSR
	xorlw	0xf0
	skpz
	goto	clear_next
	return
	
handle_serial:
	banksel	PIR1		; for testing serial data availability
	SKIP_IF_SERIAL_DATA	; return if there's no data available
	return

	banksel	0
	lcall	getch_usart
	xorlw	'*'
	skpz
	return
	
;;; valid start-of-communication byte received. Go into the command mode.
handle_command:
	fcall	getch_usart_timeout
	movwf	command
	xorlw	'g'
	skpnz
	goto	handle_g
	
	movfw	command
	xorlw	's'
	skpnz
	goto	handle_s

	movfw	command
	xorlw	'm'
	skpnz
	goto	handle_m

	movfw	command
	xorlw	'h'
	skpnz
	goto	handle_h

	movfw	command
	xorlw	'c'
	skpnz
	goto	handle_c

	movfw	command
	xorlw	'P'
	skpnz
	goto	handle_P

	movfw	command
	xorlw	'S'
	skpnz
	goto	handle_S

	movfw	command
	xorlw	'A'
	skpnz
	goto	handle_A

	movfw	command
	xorlw	'a'
	skpnz
	goto	handle_a
	
	movfw	command
	xorlw	'd'
	skpnz
	goto	handle_d

	return			; not a handled command. Done.

;;; debugging methods
handle_d:
	;; debugging: fire off the alarm.
	movlw	LIGHTS_ALARM
	movwf	desired_lamp_mode
	movlw	'+'
	lgoto	putch_usart
	
handle_g:
        lcall   RTC_brst_rd
	bankisel time_secs
	movfw	FSR
	movwf	command_tmp
	movlw	time_secs	;assumes time_secs is the start of the time buf
	movwf	FSR
	movlw	0x07		; 7 bytes of data to send
	movwf	command
send_next_date_byte:
	movfw	INDF
	incf	FSR, F
	fcall	putch_BCD_usart
	decfsz	command, F
	goto	send_next_date_byte

	movfw	command_tmp	; restore FSR
	movwf	FSR
	return

handle_s:
	bankisel time_secs
	movfw	FSR
	movwf	command_tmp
	movlw	time_secs	;assumes time_secs is the start of the time buf
	movwf	FSR
	movlw	0x07		; 7 bytes of data to send
	movwf	command
recv_next_date_byte:
	fcall	getch_usart
	movwf	INDF
	incf	FSR, F
	decfsz	command, F
	goto	recv_next_date_byte
	
	lcall	RTC_brst_wr

	movlw	'+'
	lcall	putch_usart

	movfw	command_tmp	; restore FSR
	movwf	FSR
	
	lgoto	handle_g

;;; 'm': set lamp mode
handle_m:
	lcall	getch_usart	; stick the new mode into lamp_mode
	movwf	desired_lamp_mode
	
	movlw	'+'
	lgoto	putch_usart

;;; show event history (i.e. dump 256 bytes of eeprom data - which is more
;;; than just event history, it's a full eeprom dump, but whatever)
handle_h:
	clrf	command_tmp
handle_next_h:
	movfw	command_tmp
	lcall	eep_read
	fcall	putch_usart
	incfsz	command_tmp, F
	goto	handle_next_h
	movlw	'+'
	lgoto	putch_usart

;;; clear all events:
handle_c:
	lcall	clear_all_events
	movlw	'+'
	lgoto	putch_usart

;;; start playing music:
handle_P:
	;; read in a start block (4 bytes)
        lcall    getch_usart
	banksel	mmc_block0
	movwf	mmc_block0
	banksel	0
        lcall    getch_usart
	banksel	mmc_block1
	movwf	mmc_block1
	banksel	0
        lcall    getch_usart
	banksel	mmc_block2
	movwf	mmc_block2
	banksel	0
        lcall    getch_usart
	banksel	mmc_block3
	movwf	mmc_block3
	banksel	0

	movlw	'+'
	lcall	putch_usart

	;; read in an end block (4 bytes)
        lcall    getch_usart
	banksel	end_block0
	movwf	end_block0
	banksel	0
        lcall    getch_usart
	banksel	end_block1
	movwf	end_block1
	banksel	0
        lcall    getch_usart
	banksel	end_block2
	movwf	end_block2
	banksel	0
        lcall    getch_usart
	banksel	end_block3
	movwf	end_block3
	banksel	0

	bsf	NEED_STARTPLAYING
	movlw	'+'
	lgoto	putch_usart
	

	;; "S"top playing
handle_S:
	bsf	STOP_MUSIC_NOW
	movlw	'+'
	lgoto	putch_usart

	;; set "A"larm h/m
handle_A:
        lcall   getch_usart
	movwf	alarm_h
	lcall	getch_usart
	movwf	alarm_m
	lcall	RTC_WrAlarm
	movlw	'+'
	lgoto	putch_usart

	;; show 'a'larm h/m
handle_a:
	movfw	alarm_h
	lcall	putch_usart
	movfw	alarm_m
	lcall	putch_usart
	movlw	'+'
	lgoto	putch_usart

	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"main.asm crosses a page boundary"
	endif
	
	END
	