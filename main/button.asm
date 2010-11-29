;;; NOTE: must minimize 'call' in this file to reduce the stack size
;;; required. The button handler operates from the main event loop, and
;;; there's very little overhead for the event loop to use the stack
;;; (since the interrupt is using it heavily).
	
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
	include	"bcd_math.inc"
	
	GLOBAL	handle_button
	GLOBAL	ultra_long_buttonpress
	GLOBAL	button_cancel_alarm
	
button	code

	CONSTANT	_block_start = $
check_start_button:	
	
RESET_MEDIA_QUEUE	MACRO
	banksel	PLAY_TIME_QUEUE_SIZE
	bankisel	PLAY_TIME_QUEUE_SIZE
	clrf	PLAY_TIME_QUEUE_SIZE
	movlw	PLAY_TIME_QUEUE_0
	movwf	PLAY_TIME_QUEUE_PTR
	movwf	FSR
	banksel	0
	ENDM

START_PLAYING_MEDIA	MACRO
	fcall	play_it
	ENDM
	
START_PLAYING_MEDIA_INLINE	MACRO
	banksel	PLAY_TIME_QUEUE_SIZE
	
	incf	PLAY_TIME_QUEUE_SIZE, F ; add 1 to queue, which acts as a mutex
        banksel 0
	bsf     NEED_START_TIMEQUEUE
	ENDM

QUEUE_ONE_MEDIA	MACRO
	fcall	queue_it
	ENDM
	
QUEUE_ONE_MEDIA_INLINE	MACRO
        banksel PLAY_TIME_QUEUE_SIZE
        bankisel PLAY_TIME_QUEUE_SIZE
	movwf   INDF
	incf    PLAY_TIME_QUEUE_SIZE, F
	incf    FSR, F
	banksel	0
	ENDM

QUEUE_ONE_SHORT_MEDIA	MACRO
	fcall	queue_it
	ENDM
	
QUEUE_ONE_SHORT_MEDIA_INLINE	MACRO
	movwf   INDF
	incf    PLAY_TIME_QUEUE_SIZE, F
	incf    FSR, F
	ENDM
	
;;; from the hours (BCD, in W), queue appropriate media to say the given hour.
QUEUE_MEDIA_FOR_HOURS_BCD	MACRO
	fcall	from_bcd
	;; W now contains the de-BCD'd version.
	;; Now add that event to the queue.
	QUEUE_ONE_MEDIA
	ENDM

QUEUE_MEDIA_ONES	MACRO
	andlw	0x0F
	QUEUE_ONE_MEDIA
	ENDM
	
QUEUE_MEDIA_TENS	MACRO
	andlw	0x0F
	fcall	tens_years_lookup ; get "oh, ten, twenty, ..."
	QUEUE_ONE_MEDIA
	ENDM
	
;;; from the minutes (BCD, in W), queue appropriate media to say the given minutes.
QUEUE_MEDIA_FOR_MINUTES	MACRO
	LOCAL	not_zero_zero
	LOCAL	not_zero_tens
	LOCAL	not_one_ten
	LOCAL	not_two_tens
	LOCAL	not_three_tens
	LOCAL	not_four_tens
	LOCAL	done_tens
	LOCAL	done_time_queue
	LOCAL	dummy

	pagesel	dummy
dummy:
	bankisel PLAY_TIME_QUEUE_SIZE
	banksel	play_time_tmp
	movwf	play_time_tmp

	andlw	0xF0
	movwf	play_time_tmp2
	xorlw	0x00
	skpz
	goto	not_zero_tens

	;; If we have zero tens, we need to queue either "hours" (if minutes
	;; are also zero) or nothing (and skip to minutes queueing).
	movfw	play_time_tmp
	andlw	0x0F
	skpz
	goto	not_zero_zero
	
	;; It's "hours". Queue it, and we're done building the queue.
	movlw	IDX_HUNDREDHOURS
	QUEUE_ONE_SHORT_MEDIA
	goto	done_time_queue
not_zero_zero:
	;; It's an "oh". Queue it, and then go queue the minutes.
	movlw	IDX_0
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

not_zero_tens:
	movfw	play_time_tmp2
	xorlw	0x10
	skpz
	goto	not_one_ten

	;; It's one ten - which means ten, eleven, twelve, ... nineteen.
	;; Convert BCD to HEX, construct the index, and queue it and we're
	;; done.
	movfw	play_time_tmp	; get the number
	andlw	0x0F		; strip off tens
	addlw	IDX_10		; construct new index and queue it
	QUEUE_ONE_SHORT_MEDIA
	goto	done_time_queue

not_one_ten:
	movfw	play_time_tmp2
	xorlw	0x20
	skpz
	goto	not_two_tens

	movlw	IDX_20
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

not_two_tens:
	movfw	play_time_tmp2
	xorlw	0x30
	skpz
	goto	not_three_tens
	
	movlw	IDX_30
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

not_three_tens:
	movfw	play_time_tmp2
	xorlw	0x40
	skpz
	goto	not_four_tens

	movlw	IDX_40
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens
	
not_four_tens:
	;; Must be fifty; we checked everything else!
	movlw	IDX_50
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

done_tens:
	;;
	;; Now check the minutes (we get here for 0x, 2x, 3x, 4x and 5x.)
	;;
	banksel	play_time_tmp
	movfw	play_time_tmp	; get the number
	andlw	0x0F		; strip off tens
	skpnz
	goto	done_time_queue	; never queue 0 minutes as a sound.
	addlw	IDX_0		; construct new index and queue it
	QUEUE_ONE_SHORT_MEDIA
	
done_time_queue:
	banksel	0
	ENDM

;;; short verison of QUEUE_TIME_MINUTES; this version says "Oh" instead of
;;; "hundred hours", and says "one" instead of "oh one" (et al). Used during
;;; set modes.
QUEUE_SHORT_MEDIA_FOR_MINUTES	MACRO
	LOCAL	not_zero_zero
	LOCAL	not_zero_tens
	LOCAL	not_one_ten
	LOCAL	not_two_tens
	LOCAL	not_three_tens
	LOCAL	not_four_tens
	LOCAL	done_tens
	LOCAL	done_time_queue
	LOCAL	dummy

	pagesel	dummy
dummy:
	bankisel PLAY_TIME_QUEUE_SIZE
	banksel	play_time_tmp
	movwf	play_time_tmp

	andlw	0xF0
	movwf	play_time_tmp2
	xorlw	0x00
	skpz
	goto	not_zero_tens

	;; If we have zero tens, we need to queue either "hours" (if minutes
	;; are also zero) or nothing (and skip to minutes queueing).
	movfw	play_time_tmp
	andlw	0x0F
	skpz
	goto	not_zero_zero
	
	;; It's "00". Queue 'oh', and we're done building the queue.
	movlw	IDX_0
	QUEUE_ONE_SHORT_MEDIA
	goto	done_time_queue
not_zero_zero:
	;; It's an "oh". Ignore it; we'll pick it up in the ones.
	goto	done_tens

not_zero_tens:	
	movfw	play_time_tmp2
	xorlw	0x10
	skpz
	goto	not_one_ten

	;; It's one ten - which means ten, eleven, twelve, ... nineteen.
	;; Convert BCD to HEX, construct the index, and queue it and we're
	;; done.
	movfw	play_time_tmp	; get the number
	andlw	0x0F		; strip off tens
	addlw	IDX_10		; construct new index and queue it
	QUEUE_ONE_SHORT_MEDIA
	goto	done_time_queue

not_one_ten:
	movfw	play_time_tmp2
	xorlw	0x20
	skpz
	goto	not_two_tens

	movlw	IDX_20
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

not_two_tens:
	movfw	play_time_tmp2
	xorlw	0x30
	skpz
	goto	not_three_tens
	
	movlw	IDX_30
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

not_three_tens:
	movfw	play_time_tmp2
	xorlw	0x40
	skpz
	goto	not_four_tens

	movlw	IDX_40
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens
	
not_four_tens:
	;; Must be fifty; we checked everything else!
	movlw	IDX_50
	QUEUE_ONE_SHORT_MEDIA
	goto	done_tens

done_tens:
	;;
	;; Now check the minutes (we get here for 0x, 2x, 3x, 4x and 5x.)
	;;
	banksel	play_time_tmp
	movfw	play_time_tmp	; get the number
	andlw	0x0F		; strip off tens
	skpnz
	goto	done_time_queue	; never queue 0 minutes as a sound.
	addlw	IDX_0		; construct new index and queue it
	QUEUE_ONE_SHORT_MEDIA
	
done_time_queue:
	banksel	0
	ENDM

;;; 
;;; handle_button
;;; 
handle_button:
	;; If there's a time queue sound playing, we don't want to touch the
	;; queue (or we'll cause a deadlock).
	banksel	PLAY_TIME_QUEUE_SIZE
	movfw	PLAY_TIME_QUEUE_SIZE
	banksel	0
	addlw	0
	skpz
	return

	pagesel	do_button
	banksel	button_state
	btfss	BUTTON_NEEDS_CLEARING
	goto	do_button

	;; if BUTTON_NEEDS_CLEARING is set, we have to wait for the button
	;; to be released before we continue. It's released when high (set).
	banksel	BUTTON_PORT
	btfss	BUTTON_PIN	; button is active-low, so skip if set (aka not pressed).
	return			; allow the other main loop functions to work, though

	;; button was released so clear the "we need the button cleared" condx
	bcf	BUTTON_NEEDS_CLEARING

do_button:
	banksel	BUTTON_PORT
	btfsc	BUTTON_PIN	;button is active-low
	return

	;; debounce: wait ~250mS before continuing. That would be 0x1312d0
	;; instruction cycles. This is about 237mS @ 20MHz.
	banksel	debounce_1
	clrf	debounce_1
	clrf	debounce_2
	clrf	debounce_3
	clrf	button_hold_tmr1
	clrf	button_hold_tmr2
	clrf	button_hold_tmr3
	pagesel	debounce_loop
debounce_loop:
	incfsz	debounce_1, F
	goto	debounce_loop
	incfsz	debounce_2, F
	goto	debounce_loop
	incf	debounce_3, F
	movfw	debounce_3
	xorlw	0x06
	skpz
	goto	debounce_loop
	banksel	0

	;; watch how long it was held down. We might want to go into a
	;; different mode depending on how long it's held.
	pagesel	handle_button_loop
handle_button_loop:
	banksel	button_hold_tmr1
	;; button_hold_tmr3 increments by 1 for every .131 seconds-ish.
	;; button_hold_tmr3 rolls over at ~ 33.6 seconds.
	;; button_hold_tmr3 == 0x1F at ~ 4.07 seconds.
	incfsz	button_hold_tmr1, F
	goto	btn_add1
	incfsz	button_hold_tmr2, F
	goto	btn_add1
	incf	button_hold_tmr3, F
	movfw	button_hold_tmr3
	xorlw	0x04
	skpnz
	goto	handle_long_buttonpress

	
btn_add1:
	banksel	BUTTON_PORT
	btfss	BUTTON_PIN	;wait for it to go high again
	goto	handle_button_loop ; okay, since we set pagesel above

	banksel	0

	;; SHORT PRESS.
	;;
	;; See if we're currently setting anything. If we are, we need to
	;; increment (and mod) its value. And if not, we'll fall through
	;; to a normal light-mode-change.

	movfw	set_time_mode
	addlw	0x00
	skpz
	goto	handle_set_mode
	movfw	set_alarm_mode
	addlw	0x00
	skpz
	goto	handle_set_mode
	
	;; 
	;; For "normal" (short) presses, change the state of the light.
	;;


	;; LIGHTS_OFF => LIGHTS_ON
	movfw	cur_lamp_mode
	xorlw	LIGHTS_OFF
	skpnz
	goto	button_turnem_on ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_OFF

	;; LIGHTS_ON => LIGHTS_MOODY
	xorlw	LIGHTS_ON
	skpnz
	goto	button_lights_moody ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ON

	;; LIGHTS_MOODY => LIGHTS_ORGAN
	xorlw	LIGHTS_MOODY
	skpnz
;;; 	goto	button_lights_organ ; okay, since pagesel is 0 from above
	;; debugging: removed lights_organ, which appears broken.
	goto	button_turnem_off ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_MOODY

	;; LIGHTS_ORGAN => LIGHTS_OFF
	xorlw	LIGHTS_ORGAN
	skpnz
	goto	button_turnem_off ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ORGAN

	;; LIGHTS_ALARM => LIGHTS_OFF and cancel the alarm
	xorlw	LIGHTS_ALARM
	skpnz
	goto	button_cancel_alarm ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ALARM

	;; LIGHTS_ALARMING => LIGHTS_OFF and cancel the alarm
	xorlw	LIGHTS_ALARMING
	skpnz
	goto	button_cancel_alarm ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ALARMING
	
	;; LIGHTS_ALERT => LIGHTS_ALERTING
	xorlw	LIGHTS_ALERT
	skpnz
	goto	button_play_alert ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ALERT
	
	;; LIGHTS_ALERTING => LIGHTS_OFF and cancel the alert
	xorlw	LIGHTS_ALERTING
	skpnz
	goto	button_cancel_alarm ; okay, since pagesel is 0 from above
	xorlw	LIGHTS_ALERTING

	;; LIGHTS_SPEAKING => LIGHTS_OFF
	xorlw	LIGHTS_SPEAKING
	skpnz
	goto	button_cancel_speaking
	xorlw	LIGHTS_SPEAKING

	;; all done checking lights modes
	return

button_turnem_on:
	movlw	LIGHTS_ON
	movwf	desired_lamp_mode
	return

button_play_alert:
	bsf	NEED_START_ALERT
	movlw	LIGHTS_ALERTING
	movwf	desired_lamp_mode
	return

button_lights_moody:
	movlw	LIGHTS_MOODY
	movwf	desired_lamp_mode
	return

button_lights_organ:
	movlw	LIGHTS_ORGAN
	movwf	desired_lamp_mode
	return

button_cancel_speaking:
	;; does same as button_cancel_alarm...
button_cancel_alarm:
	;; if we're playing or draining, then stop playing. It's possible that
	;; we've just disabled the playback, or we're in the middle of re-
	;; initializing, so some care probably makes sense.
	btfsc	MUSIC_PLAYING
	bsf	STOP_MUSIC_NOW
	btfsc	MUSIC_DRAINING
	bsf	STOP_MUSIC_NOW
	
	;; fall through to button_turnem_off
	
button_turnem_off:
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode
	return

handle_long_buttonpress:
	banksel	button_state
	bsf	BUTTON_NEEDS_CLEARING

	;; if we're in any of the set modes, then move to the next set-mode. If
	;; we're not in any set mode, then play "the time is" or "the alarm time is"
	;; depending on the position of the switch.

	movfw   set_time_mode
	iorwf   set_alarm_mode, W
	skpz
	goto	long_change_modes

	;; play the "the time is" thingamabobber. We'll build a queue of events
	;; to play in sequence. This destroys FSR.
	;;
	;; THE TIME IS...
	;;   ... hour.wav.raw
	;;   ... [?, ?, 20, 30, 40, 50]
	;;       ... where the first ? might be "hours" if mins == 0, or '0'
	;;       ... and second ? is 10-19 depending on mins
	;;   ... [blank, 1-9] based on minutes

	;; reset the playback queue
	RESET_MEDIA_QUEUE

	;; string together the playback items we'll need. This is a list of
	;; the indices into the media play table, so order is important
	movlw	IDX_TIMEIS
	QUEUE_ONE_MEDIA

	fcall	queue_current_time

	;; is the alarm switch enabled? If so, also say the alarm time.

	banksel	SWITCH_PORT
	btfsc	ALARM_ENABLE	; alarm is enabled if this is *clear*.
	goto	no_alarm_for_you
	banksel	0

	movlw	IDX_ALARMSETTO
	QUEUE_ONE_MEDIA

	banksel	0
	movfw	alarm_h
	QUEUE_MEDIA_FOR_HOURS_BCD
	
	;; 
	;; determine the minutes part of the message.
	;;
	banksel	0
	movfw	alarm_m
	QUEUE_MEDIA_FOR_MINUTES

	;; "alarm light" setting
	movlw	IDX_DEADAIR
	QUEUE_ONE_MEDIA
	movlw	IDX_ALARMLIGHT	; "Alarm light"
	QUEUE_ONE_MEDIA

	banksel	alarm_light_type
	movlw	IDX_BLUE
	btfsc	ALARM_LIGHT_WHITE
	movlw	IDX_WHITE
	btfsc	ALARM_LIGHT_DISABLED
	movlw	IDX_DISABLED
	banksel	0
	QUEUE_ONE_MEDIA
	
no_alarm_for_you:
	banksel	0

	;; see if there's a transient event for today. If so, queue it.
	
	fcall	is_event_available_np
	addlw	0x00
	skpnz
	goto	done_queue_construction

	;; there *is* an event. Is it a transient event?
	banksel	event_tmp_bit
	movfw	event_tmp_bit
	banksel	0
	addlw	0x00
	skpz
	goto	done_queue_construction ; not transient

	;; queue some dead air first...
	movlw	IDX_DEADAIR
	QUEUE_ONE_MEDIA

	;; and then the transient event
	banksel	mmc_next_mediaid
	movfw mmc_next_mediaid
	banksel	0
	QUEUE_ONE_MEDIA

done_queue_construction:	
	;; done constructing the queue. Start playing it
	START_PLAYING_MEDIA
	return
	
queue_current_time:	
	;; convert from hours to a proper queue id. This is just a matter of
	;; converting from BCD to decimal, and then using that index.
	
	banksel	time_hrs
	movfw	time_hrs
	QUEUE_MEDIA_FOR_HOURS_BCD

	;; 
	;; determine the minutes part of the message.
	;; 
	banksel	time_mins
	movfw	time_mins
	QUEUE_MEDIA_FOR_MINUTES

	;; if alarm switch is on, we skip the date
	banksel	SWITCH_PORT
	btfss	ALARM_ENABLE	; alarm is enabled if this is *clear*.
	return

	banksel	0
	
	;; short pause...
	movlw	IDX_DEADAIR
	QUEUE_ONE_MEDIA
	
	banksel	time_dow
	movfw	time_dow
	addlw	IDX_SUNDAY-1
	
	QUEUE_ONE_MEDIA
	
	banksel	time_mon
	movfw	time_mon
	addlw	IDX_JANUARY-1	; time_mon is 1-based.
	
	QUEUE_ONE_MEDIA

	banksel	time_days
	movfw	time_days
	QUEUE_SHORT_MEDIA_FOR_MINUTES

	;; FIXME: need a "two thousand and"?
	
	banksel	time_yrs
	movfw	time_yrs
	QUEUE_MEDIA_FOR_MINUTES	; will sound bad in 2000, but that's already passed!
	
	return

;;;
;;; long_change_modes is called when a long press is detected and we're in any of
;;; the "set" modes. could be alarm or time setting though.
long_change_modes:
	movfw	set_time_mode
	addlw	0
	skpz
	goto	long_change_time_mode

	;; Move the alarm to the next alarm mode.
	clc
	rlf	set_alarm_mode, F

	RESET_MEDIA_QUEUE
	
	;; it's an alarm-change-time-mode. Move to the next mode.
	btfss	SET_ALARM_TEN_MINUTES
	goto	not_set_alarm_ten_minutes

	movlw	IDX_SETALARM	; "Set Alarm"
	QUEUE_ONE_MEDIA
	movlw	IDX_TENSOFMINUTES ; "Tens of Minutes"
	QUEUE_ONE_MEDIA

	banksel	alarm_m
	swapf	alarm_m, W
	banksel	0
	QUEUE_MEDIA_TENS
	
	START_PLAYING_MEDIA
	return

	
not_set_alarm_ten_minutes:
	;; Were we in "set alarm ten_mintues"?
	btfss	SET_ALARM_ONES_MINUTES
	goto	not_set_alarm_ones_minutes

	movlw	IDX_SETALARM	; "Set Alarm"
	QUEUE_ONE_MEDIA
	movlw	IDX_ONESOFMINUTES ; "Tens of Minutes"
	QUEUE_ONE_MEDIA

	banksel	alarm_m
	movfw	alarm_m
	banksel	0
	QUEUE_MEDIA_ONES
	
	START_PLAYING_MEDIA
	return

	
not_set_alarm_ones_minutes:
	btfss	SET_ALARM_LAMP
	goto	not_set_alarm_lamp

	movlw	IDX_ALARMLIGHT	; "Alarm light"
	QUEUE_ONE_MEDIA

	banksel	alarm_light_type
	movlw	IDX_BLUE
	btfsc	ALARM_LIGHT_WHITE
	movlw	IDX_WHITE
	btfsc	ALARM_LIGHT_DISABLED
	movlw	IDX_DISABLED

	QUEUE_ONE_MEDIA

	START_PLAYING_MEDIA
	return

not_set_alarm_lamp:
	;; Okay, we're done setting the alarm. (Must have been "set alarm lamp".)
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode

	movlw	IDX_ALARMSETTO
	QUEUE_ONE_MEDIA

	banksel	alarm_h
	movfw	alarm_h
	banksel	0
	QUEUE_MEDIA_FOR_HOURS_BCD

	banksel	alarm_m
	movfw	alarm_m
	QUEUE_MEDIA_FOR_MINUTES
	banksel	0
	
	clrf	set_alarm_mode

	lcall	RTC_WrAlarm
	
	START_PLAYING_MEDIA
	return

	
long_change_time_mode:
	;; we're in set_time mode, and need to handle a long press (to change to
	;; the next set-value). Hours => minutes => tens of years => ones of years =>
	;; month => day => day of week => done

	RESET_MEDIA_QUEUE	; going to have to do this anyway...

	;; advance the step-timer.
	clc
	rlf	set_time_mode, F ; move to the next set-mode. Now figure out what it is
	movfw	set_time_mode
	addlw	0x00
	skpnz
	goto	finish_time_change_mode ; all done!

	btfsc	SET_TIME_TEN_MINUTES
	movlw	IDX_SETTIME
	btfsc	SET_TIME_ONES_MINUTES
	movlw	IDX_SETTIME
	btfsc	SET_TIME_TENS_YEAR
	movlw	IDX_SETTENSOFYEAR
	btfsc	SET_TIME_ONES_YEAR
	movlw	IDX_SETONESOFYEAR
	btfsc	SET_TIME_MONTH
	movlw	IDX_SETMONTH
	btfsc	SET_TIME_DAY
	movlw	IDX_SETDAY
	btfsc	SET_TIME_DOW
	movlw	IDX_SETDOW

	;; speak the new mode and say its current value.
	QUEUE_ONE_MEDIA

	banksel	0
	

	;; now play the value for each of those settings.
	
	btfss	SET_TIME_TEN_MINUTES
	goto	local_1
	banksel	0
	movlw	IDX_TENSOFMINUTES
	QUEUE_ONE_MEDIA

	banksel	time_mins
	swapf	time_mins, W
	QUEUE_MEDIA_TENS
	goto	done_time_change
local_1:
	btfss	SET_TIME_ONES_MINUTES
	goto	local_2
	movlw	IDX_ONESOFMINUTES
	QUEUE_ONE_MEDIA
	banksel	time_mins
	movfw	time_mins
	banksel	0
	QUEUE_MEDIA_ONES
	goto	done_time_change
local_2:	
	btfsc	SET_TIME_TENS_YEAR
	goto	play_time_tens_years

	btfss	SET_TIME_ONES_YEAR
	goto	local_3
	movfw	time_yrs
	banksel	0
	QUEUE_MEDIA_ONES
	goto	done_time_change
local_3:
	btfss	SET_TIME_MONTH
	goto	local_4
	movfw	time_mon
	goto	play_time_mon
local_4:
	btfsc	SET_TIME_DAY
	goto	play_time_days

	;; must be Day-Of-Week if we got here...
	goto	play_time_dow

finish_time_change_mode:
	banksel	0
	clrf	set_time_mode

	;; turn off the green light we were pulsating.
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode
	
	;; say "time set to"

	movlw	IDX_TIMESETTO
	QUEUE_ONE_MEDIA
	
	;; update the RTC chip, but clear the seconds.
	banksel	time_secs
	clrf	time_secs
	fcall	RTC_brst_wr

	;; speak the end-of-time-set-mode jabber (that's the current time).

	fcall	queue_current_time
	;; fall through to start_playing_media and return

done_time_change:
	START_PLAYING_MEDIA

	return
	
;;;
;;; handle_set_mode takes care of incrementing the various time/alarm values,
;;; usw.
handle_set_mode:
	btfsc	SET_TIME_HOURS
	goto	inc_time_hours
	btfsc	SET_TIME_TEN_MINUTES
	goto	inc_time_tens_minutes
	btfsc	SET_TIME_ONES_MINUTES
	goto	inc_time_ones_minutes
	btfsc	SET_TIME_TENS_YEAR
	goto	inc_time_tens_year
	btfsc	SET_TIME_ONES_YEAR
	goto	inc_time_ones_year
	btfsc	SET_TIME_MONTH
	goto	inc_time_month
	btfsc	SET_TIME_DAY
	goto	inc_time_day
	btfsc	SET_TIME_DOW
	goto	inc_time_dow
	btfsc	SET_ALARM_HOURS
	goto	inc_alarm_hours
	btfsc	SET_ALARM_TEN_MINUTES
	goto	inc_alarm_tens_minutes
	btfsc	SET_ALARM_ONES_MINUTES
	goto	inc_alarm_ones_minutes
	btfsc	SET_ALARM_LAMP
	goto	inc_alarm_lamp
	return			; shouldn't happen!

inc_time_hours:
	movfw	time_hrs
	banksel	0
	fcall	from_bcd
	addlw	0x01
	;; did we roll over?
	xorlw	d'24'
	skpnz
	movlw	d'24'		; will wind up turning it back into 0 here...
	xorlw	d'24'		; undo "damage" from first xor (or turn into 0
	fcall	to_bcd		;  if we rolled over). Then convert back to BCD
	movwf	time_hrs	;  and store it as the new hours value.
	;; time_hrs contains the BCD version of the hours now. Announce it too

	RESET_MEDIA_QUEUE
	movfw	time_hrs
	QUEUE_MEDIA_FOR_HOURS_BCD
	START_PLAYING_MEDIA
	return
	
inc_time_tens_minutes:
	banksel	time_mins
	movlw	0x10		; add ten minutes (BCD)
	addwf	time_mins, F
	movfw	time_mins	; see if we hit 0x60 minutes, and if so, wrap
	andlw	0xF0
	xorlw	0x60
	skpnz
	bcf	time_mins, 6	; if we hit 0xA0, make it 0x00 by clearing 2 
	skpnz
	bcf	time_mins, 5	;   bits (since 0x6y == %0110yyyy)

;;;  play the tens of number of minutes.
	banksel	0
	RESET_MEDIA_QUEUE
	banksel	time_mins
	swapf	time_mins, W
	banksel	0
	QUEUE_MEDIA_TENS
	START_PLAYING_MEDIA
	return

inc_time_ones_minutes:
	RESET_MEDIA_QUEUE	; to avoid clobbering the W register later

	banksel	time_mins
	incf	time_mins, F
	movfw	time_mins
	andlw	0x0F
	xorlw	0x0A		;did we reach 10 ones?
	skpnz
	bcf	time_mins, 3	; if we hit 10 ones, clear the bits
	skpnz
	bcf	time_mins, 1	;  ... more clearing of bits to make it 0 ones
	movfw	time_mins	; get a clean copy with bits mod'd if apropos
	andlw	0x0F		;   we just want the minutes

	;; 'W' still contains the ones. Play that media file (IDX_0 through IDX_9)

	QUEUE_ONE_MEDIA
	
	START_PLAYING_MEDIA
	
	return

inc_time_tens_year:
	banksel	time_yrs	
	movlw	0x10		; add ten years (BCD)
	addwf	time_yrs, F
	movfw	time_yrs	; see if we hit 0xA0 years, and if so, wrap
	andlw	0xF0
	xorlw	0xA0
	skpnz
	bcf	time_yrs, 7	; if we hit 0xA0, make it 0x00 by clearing 2 
	skpnz
	bcf	time_yrs, 5	;   bits (since 0xA0 == %10100000)

;;;  play the tens of number of years.
	banksel	0
	RESET_MEDIA_QUEUE

play_time_tens_years:
	banksel	time_yrs
	swapf	time_yrs, W
	banksel	0
	QUEUE_MEDIA_TENS
	
	START_PLAYING_MEDIA

	return
	
inc_time_ones_year:
	RESET_MEDIA_QUEUE	; to avoid clobbering the W register later

	banksel	time_yrs
	incf	time_yrs, F
	movfw	time_yrs
	andlw	0x0F
	xorlw	0x0A		;did we reach 10 ones?
	skpnz
	bcf	time_yrs, 3	; if we hit 10 ones, clear the bits
	skpnz
	bcf	time_yrs, 1	;  ... more clearing of bits to make it 0 ones
	movfw	time_yrs	; get a clean copy with bits mod'd if apropos
	andlw	0x0F		;   we just want the minutes

	;; 'W' still contains the ones. Play that media file (IDX_0 through IDX_9)

	QUEUE_ONE_MEDIA
	
	START_PLAYING_MEDIA
	
	return
	
inc_time_month:
	RESET_MEDIA_QUEUE	; to avoid clobbering the W register later

	banksel	time_mon
	movfw	time_mon	; month should be 1-12. So do 0-11, and then add one.
	;; it's now 0-11, + 1. If we hit 12, then go back to 0.
	fcall	from_bcd
	xorlw	d'12'
	skpnz
	movlw	d'12'		; will reset to 0 after the following xor
	xorlw	d'12'		; undo damage
	addlw	1		; ... convert back to 1-12
	fcall	to_bcd
	banksel	time_mon
	movwf	time_mon

play_time_mon:	
	fcall	from_bcd
	addlw	IDX_JANUARY-1	; -1, b/c we're one-based for this value

	QUEUE_ONE_MEDIA
	
	START_PLAYING_MEDIA
	return

inc_time_day:
	movfw	time_days
	fcall	from_bcd
	addlw	1
	xorlw	d'32'		; if we hit 32, then roll over...
	skpnz
	movlw	d'32' ^ d'1'	; ... and roll over to 1, not 0
	xorlw	d'32'		; undo damage from first xor
	fcall	to_bcd
	movwf	time_days
	
	RESET_MEDIA_QUEUE

play_time_days
	movfw	time_days
	QUEUE_SHORT_MEDIA_FOR_MINUTES
	
	START_PLAYING_MEDIA

	return
	
inc_time_dow:
	movfw	time_dow
	addlw	1
	xorlw	d'8'
	skpnz
	movlw	d'8'^d'1'	;want it to become '1'
	xorlw	d'8'
	movwf	time_dow

	RESET_MEDIA_QUEUE
play_time_dow:	
	movfw	time_dow
	addlw	IDX_SUNDAY-1
	QUEUE_ONE_MEDIA
	
	START_PLAYING_MEDIA
	return
	
inc_alarm_hours:
	banksel	alarm_h
	movfw	alarm_h
	banksel	0
	banksel	0
	fcall	from_bcd
	addlw	1
	xorlw	d'24'
	skpnz
	movlw	d'24'
	xorlw	d'24'
	fcall	to_bcd
	banksel	alarm_h
	movwf	alarm_h
	
	RESET_MEDIA_QUEUE
	movfw	alarm_h
	QUEUE_MEDIA_FOR_HOURS_BCD
	START_PLAYING_MEDIA
	return
	
inc_alarm_tens_minutes:
	banksel	alarm_m
	movlw	0x10		; add ten minutes (BCD)
	addwf	alarm_m, F
	movfw	alarm_m		; see if we hit 0x60 minutes, and if so, wrap
	andlw	0xF0
	xorlw	0x60
	skpnz
	bcf	alarm_m, 6	; if we hit 0xA0, make it 0x00 by clearing 2 
	skpnz
	bcf	alarm_m, 5	;   bits (since 0x6y == %0110yyyy)

;;;  play the tens of number of minutes.
	banksel	0
	RESET_MEDIA_QUEUE
	banksel	alarm_m
	swapf	alarm_m, W
	banksel	0
	QUEUE_MEDIA_TENS
	START_PLAYING_MEDIA
	return

inc_alarm_ones_minutes:
	RESET_MEDIA_QUEUE	; to avoid clobbering the W register later

	banksel	alarm_m
	incf	alarm_m, F
	movfw	alarm_m
	andlw	0x0F
	xorlw	0x0A		;did we reach 10 ones?
	skpnz
	bcf	alarm_m, 3	; if we hit 10 ones, clear the bits
	skpnz
	bcf	alarm_m, 1	;  ... more clearing of bits to make it 0 ones
	movfw	alarm_m		; get a clean copy with bits mod'd if apropos
	andlw	0x0F		;   we just want the minutes

	;; 'W' still contains the ones. Play that media file (IDX_0 through IDX_9)

	QUEUE_ONE_MEDIA
	
	START_PLAYING_MEDIA
	
	return

inc_alarm_lamp:
	RESET_MEDIA_QUEUE
	banksel	alarm_light_type
	rlf	alarm_light_type, F
	btfsc	ALARM_LIGHT_INVALID ; if invalid, set back to blue (in 4 steps)
	bsf	ALARM_LIGHT_BLUE
	btfsc	ALARM_LIGHT_INVALID
	bcf	ALARM_LIGHT_INVALID

	banksel	0
	movlw	IDX_BLUE
	btfsc	ALARM_LIGHT_WHITE
	movlw	IDX_WHITE
	btfsc	ALARM_LIGHT_DISABLED
	movlw	IDX_DISABLED

	QUEUE_ONE_MEDIA

	START_PLAYING_MEDIA
	return
	
;;;
;;; ultra_long_buttonpress: the button was held all the way through a
;;; "speaking" event.
;;;
ultra_long_buttonpress:
	;; if we're in any of the "set" modes, then do nothing; an ultra-long press
	;; might come in before we're done timing out for a normal long press.

        movfw   set_time_mode
	iorwf   set_alarm_mode, W
	skpz
	return

	;; enter either set-time-mode or set-alarm-mode, depending on which way the
	;; alarm switch is set.

	btfsc	ALARM_ENABLE	; alarm is enabled if this is *clear*.
	goto	ul_press_time

	;; ultra-long press with alarm enable switch turned on: change the alarm time. Pulse blue while doing that.
	movlw	LIGHTS_SETALARM
	movwf	desired_lamp_mode

	bsf	SET_ALARM_HOURS
	banksel	0
	RESET_MEDIA_QUEUE
	movlw	IDX_SETALARMHOUR
	QUEUE_ONE_MEDIA

	banksel	0
	movfw	alarm_h
	QUEUE_MEDIA_FOR_HOURS_BCD
	
	START_PLAYING_MEDIA
	return
ul_press_time:
	;; start setting the time. Pulsate the green light while we're doing it
	movlw	LIGHTS_SETTIME
	movwf	desired_lamp_mode

	bsf	SET_TIME_HOURS
	RESET_MEDIA_QUEUE
	movlw	IDX_SETTIMEHOUR
	QUEUE_ONE_MEDIA

	banksel	time_hrs
	movfw	time_hrs
	QUEUE_MEDIA_FOR_HOURS_BCD
	
	START_PLAYING_MEDIA
	return

queue_it:
	QUEUE_ONE_MEDIA_INLINE
	return

play_it:	
	START_PLAYING_MEDIA_INLINE
	return
	
check_end_button:
	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"button.asm crosses a page boundary"
	endif

	;; slip this in to a small chunk of memory before the main loop
	org	0xf5
tens_years_lookup:
	addwf	PCL, F
	retlw	IDX_0
	retlw	IDX_10
	retlw	IDX_20
	retlw	IDX_30
	retlw	IDX_40
	retlw	IDX_50
	retlw	IDX_60
	retlw	IDX_70
	retlw	IDX_80
	retlw	IDX_90

	END
	
	