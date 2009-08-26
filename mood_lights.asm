	include	"processor_def.inc"
	include	"constants.inc"
	include	"memory.inc"
	include	"common.inc"
	include "events.inc"
	include "maxm.inc"
	include "serial.inc" 	;debug
	
	GLOBAL mood_handler
	GLOBAL pulsation_handler

.string	CODE
msg_ctableerr:	
	da	"Ctable goto error: 0x"
	dw	0x0000
	
moodlights	CODE

	;; THERE IS A BUG IN THIS CODE. The computed goto table in the middle
	;; of this module (for desired_lamp_mode, search for "PCL, F") doesn't
	;; function properly if we get *near* the end of a page. Obviously,
	;; it wouldn't work correctly if we actually *Crossed* the page
	;; boundary - but I never thought it would die if the computed goto
	;; was jumping to addresses near  0x1750. But, nonetheless, it fails
	;; under those circumstances. Working around it by setting a hard
	;; org for this module that will prevent such an occurrence.
	org	0x1000

	CONSTANT	_block_start = $
check_start_moodlights:	
	;; ensure we won't change a page boundary in this code (which uses
	;; a lot of 'goto'), and also make sure it's in the same codepage
	;; as the interrupt handler.

	
;;; PWM code for three lights (R, G, B) and functions to make them mood-y.
;;; Light modes are enumerated in constants.inc.

mood_handler:
	;; if we're in the target mode, then we're done checking the modes.
	pagesel	pwm_maint
	movfw	cur_lamp_mode
	xorwf	desired_lamp_mode, W
	skpnz			;if they're equal, this will now be zero
	goto    pwm_maint ; already in the desired mode.

	;; update the current mode value with whatever we're changing to.
	movfw	desired_lamp_mode
	movwf	cur_lamp_mode

	;; get the appropriate initializer's code routine from the dispatch
	;; table.
	pagesel	$
	banksel	0

	;; make sure we're not beyond LIGHTS_SETALARM. If we are, that's a
	;; problem.
	movfw	desired_lamp_mode
	sublw	LIGHTS_SETALARM
	skpwle
	goto	table_error

	movfw	desired_lamp_mode
	addwf	PCL, F
	goto	all_off		; LIGHTS_OFF = 0
	goto	all_on		; LIGHTS_ON  = 1
	goto	moody_on	; LIGHTS_MOODY = 2
	goto	organ_on	; LIGHTS_ORGAN = 3
	goto	alarm_on	; LIGHTS_ALARM = 4
	goto	alert_on	; LIGHTS_ALERT = 5
	goto	alarming_on	; LIGHTS_ALARMING = 6
	goto	alerting_on	; LIGHTS_ALERTING = 7
	goto	speaking_on	; LIGHTS_SPEAKING = 8
	goto	settime_on	; LIGHTS_SETTIME = 9
	goto	setalarm_on	; LIGHTS_SETALARM = 10

table_error:	
	;; An error occurred; tried to go to a computed value that's too high.
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_ctableerr
	movfw	desired_lamp_mode
	fcall	putch_hex_usart
	;; ... and fall through
	
;;; All of those 'goto's will come back here when they're done. This eliminates
;;; the need for another depth of call stack, and also means the dispatch table
;;; is clean (don't have to call/goto, which would increase its size by 2x).
pwm_maint:

	;; if we're in mood lamp mode, do some work on the state of the
	;; r/g/b lamps. This is called 9.54 times per second.
	movlw	LIGHTS_MOODY
	xorwf	cur_lamp_mode, W
	skpz
	return

	;; delay: make it once every second, instead of a tenth.
	incf	mood_delay
	movfw	mood_delay
	xorlw	0x0a
	skpz
	return

	clrf	mood_delay
	bsf MOOD_LIGHT_NEEDS_STEPPING
	return

all_off:
	lgoto	maxm_all_off			    ; will exit from mood code completely

all_on:
	fcall	maxm_full_white
	goto	pwm_maint	; go back to the PWM handler now

;;; settime_on
settime_on:
	fcall	maxm_full_green
	return

;;; setalarm_on
setalarm_on:
	fcall	maxm_full_blue
	return

;;; speaking_on, alerting_on
speaking_on:
	;; speaking_on is the same as alerting_on
alerting_on:
	;; set R/G/B to off, so the user isn't tempted to push the button
	;; a second time immediately and cancel the mode.
	fcall	maxm_all_off
	goto	pwm_maint	; go back to the PWM handler now
	
alarming_on:
	;; set full red/green/blue.
	fcall	maxm_full_white
	goto	pwm_maint	; go back to the PWM handler now

;;; organ_on is not currently implemented
organ_on:
	goto	pwm_maint
	
moody_on:
	banksel	0
	fcall	maxm_mood_light
	goto	pwm_maint	; go back to the PWM handler now	

;;; alarm mode needs to reset the lights to full off, and slowly increase
;;; the blue light (over 20 minutes) until it reaches full brightness. When
;;; we hit that point, start playing the alarm music.
alarm_on:
	clrf	alarm_brightness_delay
	clrf	alarm_brightness_value
	incf	alarm_brightness_value, F
	
perform_alarm_lights:

	btfsc	ALARM_LIGHT_DISABLED
	goto	no_alarm_lights ; skip the brightness warm-up; just turn on music!

	;; We run this 9.54 times per second (running from TMR1). We have
	;; 255 (0xFF) brightness levels to run through before the alarm
	;; starts sounding, and we want that to happen as close as possible
	;; to a half hour from when the light started. So we want to increase
	;; the level once every 7.03125 seconds (30*60/256). Since we're called
	;; every 1/9.54 seconds, that's about 67 times
	;; 	(7.03125*9.54 = 67.078125)
	;; 67 == 0x43. The error is .078125*256: about 20 seconds.
	incf	alarm_brightness_delay, F
	movlw	0x43
	xorwf	alarm_brightness_delay, W
	skpz
	return

no_alarm_lights:	
	;; passed the timeout test. Move to next brightness level.
	incf	alarm_brightness_value, F

	clrf	alarm_brightness_delay ; reset the counter

	;; If we've wrapped around alarm_brightness_value, then start playing
	;; music.
	movfw	alarm_brightness_value
	addlw	0x00
	skpnz
	goto	end_alarm_cycle

	;; set LEDs to appropriate value (blue or white, depending on setting)
	movfw	alarm_brightness_value
	pagesel	maxm_fade_blue
	btfsc	ALARM_LIGHT_BLUE
	call	maxm_fade_blue
	pagesel	maxm_fade_white
	btfss	ALARM_LIGHT_BLUE
	call	maxm_fade_white
	return			;done with alarm for now

end_alarm_cycle:	
	;; light has finished brightening. Set to full white and start music
	fcall	maxm_full_white
	;; time to start playing music. Move to LIGHTS_ALARMING.
	movlw	LIGHTS_ALARMING	; turn on the light
	movwf	desired_lamp_mode
	bsf	NEED_START_ALARM ; will start playing the sound

	return			; Finally complete with alarm event

;;; alert mode needs to reset the lights to full off, and periodically
;;; do a fast pulse of red.
alert_on:
	fcall	maxm_pulse_red
	goto	pwm_maint	; done with alarm mode

pulsation_handler:
	;; if we're in alarm mode, we need to do some maintenance.
	pagesel	perform_alarm_lights
	movfw	cur_lamp_mode
	xorlw	LIGHTS_ALARM
	skpnz
	goto	perform_alarm_lights
	return
	
check_end_moodlights:
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"mood_lights.asm crosses a page boundary"
	endif
	
	END
	