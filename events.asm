	include	"processor_def.inc"
	include "memory.inc"
	include	"piceeprom.inc"
	include "constants.inc"
	include "sd_spi.inc"
	include "music.inc"
	include "ds1307-i2c.inc"
	include "common.inc"
	include "serial.inc"

#if 0
	GLOBAL	has_event_happened
#endif
	GLOBAL	set_event_happened
	GLOBAL	clear_all_events
	GLOBAL	start_alarm_event
	GLOBAL	start_playing_alert_event
	GLOBAL	start_playing_time_queue
	GLOBAL	is_event_available
	GLOBAL	is_event_available_np
	
events	CODE

	CONSTANT	_block_start = $
check_start_events:	
	;; this code should be able to live in any page.

 	errorlevel -306		; suppress warnings about pages
	
;;; PIC eeprom memory is used to store the bit flags for events that have
;;; happened. Event 0 is bit 0 of byte 0. Event 1 is bit 1 of byte 0. Event 8
;;; is bit 0 of byte 1. And so on.

;;; event number: byte# is in arg2, bit pattern is in arg1. returns 1 in W
;;; for yes, 0 for no.
#if 0
;;; This is a fine reference implementation, but it's not actually used; an
;;; inline version (that also does more) is being used elsewhere.
has_event_happened:
	movfw	arg2
	fcall	eep_read
	andwf	arg1, W
	skpz
	retlw	0x01
	retlw	0x00
#endif
	
;;; Set an event has having happened - the event's byte is in event_tmp_id,
;;; and its bit pattern is event_tmp_bit.
set_event_happened:
	pagesel	set_event_happened ; for debugging/disassembly. not act'l nec'y

	;; Check to see if it's a transient ram-based event, or if it's a
	;; permanent, fire-once, eeprom-based event. It's the former if the
	;; bit mask is 0x00...
	banksel	event_tmp_bit
	movfw	event_tmp_bit
	addlw	0x00
	skpz
	goto	not_transient
	
	;; transient event! Set the correct RAM address and be done
	bankisel	0x1A0
	banksel	event_tmp_id
	movfw	event_tmp_id
	movwf	FSR
	movlw	0x01
	movwf	INDF		; set memory to 0x01 appropriately
	banksel	0
	return
not_transient:	
	banksel	event_tmp_id
	movfw	event_tmp_id
	banksel	0
	movwf	arg2
	fcall	eep_read
	banksel	event_tmp_bit
	iorwf	event_tmp_bit, W
	banksel	0
	lgoto	eep_write

;;; clear_all_events
clear_all_events:
	;; first 16 bytes of eeprom memory are reserved. Others are for events
	movlw	0x10
	movwf	arg2

	bcf	INTCON, GIE
	
clear_next:
	movlw	0x00
	fcall	eep_write
	incfsz	arg2, F
	goto	clear_next
	
	return

;;; * is_event_available
;;; *  retlw 0x01 if there's something available today.
;;; *  leave the event information (number & bit) in event_tmp_id and
;;; *    event_tmp_bit.
;;; *
;;; * The _np variant will return transient events, even if they've been
;;; * triggered today ("non-persistent").
is_event_available_np:
	banksel	event_np_flag
	bsf	event_np_flag, 0
	banksel	0
	goto	event_checker_core

is_event_available:
	banksel	event_np_flag
	clrf	event_np_flag
	banksel	0

event_checker_core:	
	;; spin through the events block and see if any of them is
	;;  (a) supposed to happen today or previously,
	;;  (b) has not yet happened

	banksel	mmc_block0
	clrf	mmc_block0
	clrf	mmc_block1
	clrf	mmc_block2
	clrf	mmc_block3
	clrf	end_block0
	clrf	end_block1
	clrf	end_block2
	clrf	end_block3
	banksel	0
	fcall	mmc_start_read
        xorlw   0x01		; successful start of read?
	skpz
	retlw	0x00		; Failed to init MMC: return "no events now"
	
	goto	read_next_event	

;;; * start_playing_time_queue will test if there are any more queued events
;;; * to play. If not, it shuts off the lights.
;;; * But if so, it starts playing the next one and updates the queue pointers.
start_playing_time_queue:
	banksel	PLAY_TIME_QUEUE_SIZE
	decf	PLAY_TIME_QUEUE_SIZE, F ; pre-decrement, so that the queue stays locked properly
	movfw	PLAY_TIME_QUEUE_SIZE
	addlw	0x00		; movfw doesn't update the Z register
	skpz
	goto	continue_play_time_queue

	;; Nothing left in queue! All done...
        banksel 0
	bcf     AUDIO_ENABLE	; disable audio amplifier
	banksel	music_control
	bsf	STOP_MUSIC_NOW
	;; if we're not in LIGHTS_SETTIME or LIGHTS_SETALARM, turn off the
	;; lights.
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETTIME
	skpnz
	goto	dont_turnoff_lights
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETALARM
	skpnz
	goto	dont_turnoff_lights
	;; okay, turn them off...
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode
dont_turnoff_lights:	
	;; also check to see if it was an ultra-long button press (if it's
	;; still held at the end of the event, essentially). If so, we'll
	;; flag that we need to handle that, too.
	banksel	BUTTON_PORT
	btfsc	BUTTON_PIN	; active-low.
	return
	banksel	button_state
	bsf	BUTTON_HELD_ULTRA_LONG
	return

continue_play_time_queue:
	banksel	music_control

	;; if we're in LIGHTS_SPEAKING, LIGHTS_SETTIME or LIGHTS_SETALARM
	;; modes, don't do anything - but if not, then set LIGHTS_SPEAKING.

	movfw	desired_lamp_mode
	xorlw	LIGHTS_SPEAKING
	skpnz
	goto	local1
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETTIME
	skpnz
	goto	local1
	movfw	desired_lamp_mode
	xorlw	LIGHTS_SETALARM
	skpnz
	goto	local1

	;; not in any of those modes, so set LIGHTS_SPEAKING mode.
	movlw	LIGHTS_SPEAKING
	movwf	desired_lamp_mode

local1:	
	;; play the next item in the queue. First we need to retrieve it.
	banksel	PLAY_TIME_QUEUE_PTR
	movfw	PLAY_TIME_QUEUE_PTR
	movwf	FSR
	movfw	INDF
	movwf	play_time_tmp
	incf	PLAY_TIME_QUEUE_PTR, F
	;; don't decrement the queue size here; we'll do it at the start of the
	;; next play cycle, so that we keep the queue effectively "locked"
	;; while we're playing this sample.
	;; decf	PLAY_TIME_QUEUE_SIZE, F
	
	
	;; Now: need to translate that index ID into a media start/stop block.
	;; The index number is in W (also play_time_tmp).
	banksel	0
	fcall	find_media_block

	banksel 0
	bsf	NEED_STARTPLAYING
	return
	
;;; * start_alert_event assumes that is_event_available already preloaded
;;; * all of the relevent information: mmc_next_block[], end_block[], the
;;; * event's ID in event_tmp_id, and its bit in event_tmp_bit. It will start
;;; * playing the audio, and assumes that the light is in the right mode.
start_playing_alert_event:
	banksel mmc_next_block0
	movfw   mmc_next_block0
	movwf	mmc_block0
	movfw   mmc_next_block1
	movwf	mmc_block1
	movfw   mmc_next_block2
	movwf	mmc_block2
	movfw   mmc_next_block3
	movwf	mmc_block3

	banksel 0
	lgoto	start_playing
	
;;; * start_alarm_event
	
start_alarm_event:
	movlw	's'		;debug
	fcall	putch_usart	;debug
	banksel	mmc_block0
	clrf	mmc_block0
	clrf	mmc_block1
	clrf	mmc_block2
	clrf	mmc_block3
	clrf	end_block0
	clrf	end_block1
	clrf	end_block2
	clrf	end_block3
	banksel	0
	fcall	mmc_start_read
        xorlw   0x01
	skpnz
	goto	continue_alarm_setup
	;; Failed to initialize MMC card.
	;; FIXME: what to do??
	return

continue_alarm_setup:	
	;; it's an alarm event. Read the alarm start/end block numbers.
	fcall	mmc_read_next
	banksel	mmc_next_block3
	movwf	mmc_next_block3
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block2
	movwf	mmc_next_block2
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block1
	movwf	mmc_next_block1
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block0
	movwf	mmc_next_block0
	banksel	0

	fcall	mmc_read_next
	banksel	end_block3
	movwf	end_block3
	banksel	0
	fcall	mmc_read_next
	banksel	end_block2
	movwf	end_block2
	banksel	0
	fcall	mmc_read_next
	banksel	end_block1
	movwf	end_block1
	banksel	0
	fcall	mmc_read_next
	banksel	end_block0
	movwf	end_block0
	banksel	0

	FINISH_READING_INLINE

	;; now set up the address for our next start-of-read.
	banksel mmc_next_block0
	movfw   mmc_next_block0
	movwf	mmc_block0
	movfw   mmc_next_block1
	movwf	mmc_block1
	movfw   mmc_next_block2
	movwf	mmc_block2
	movfw   mmc_next_block3
	movwf	mmc_block3
	banksel 0

	bsf	NEED_STARTPLAYING
	return

;;; find_media_block: take a media index in W, find the right start/stop
;;; blocks for that media ID, and put them into mmc_block and end_block.
;;; does not start playing; that's the responsibility of the caller.
;;; has a retlw 0x01 at its end so that it also doubles as the last half
;;; of read_next_event (where an event is found and should be played).
find_media_block:
	movwf	arg2		; hang on to a copy of the ID we want

	;; set up MMC to read from block #1 (the media directory block).
        banksel mmc_block0
	movlw	0x03		; location of media on the SD card: @ block 0x03.
	movwf	mmc_block0	; (must match what the card creator did.)
	clrf    mmc_block1
	clrf    mmc_block2
	clrf    mmc_block3
	clrf    end_block0
	clrf    end_block1
	clrf    end_block2
	clrf    end_block3
	banksel 0

	MMC_START_READ_INLINE

	xorlw   0x01    ; successful init?
	skpz
	retlw	0x00		;FIXME: not the ideal behavior, is it?

	;; read the start/end addys. We need to loop until we get to the index
	;; we want.
media_read_loop:	
	fcall	mmc_read_next
	banksel	mmc_next_block3
	movwf	mmc_next_block3
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block2
	movwf	mmc_next_block2
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block1
	movwf	mmc_next_block1
	banksel	0
	fcall	mmc_read_next
	banksel	mmc_next_block0
	movwf	mmc_next_block0
	banksel	0

	fcall	mmc_read_next
	banksel	end_block3
	movwf	end_block3
	banksel	0
	fcall	mmc_read_next
	banksel	end_block2
	movwf	end_block2
	banksel	0
	fcall	mmc_read_next
	banksel	end_block1
	movwf	end_block1
	banksel	0
	fcall	mmc_read_next
	banksel	end_block0
	movwf	end_block0
	banksel	0

	;; Now see if that's the right one - if arg2 == 0, it is. else decf
	;; and loop
	movfw	arg2
	xorlw	0x00
	skpnz
	goto	done_media_readloop
	;; not there yet - go read the next one
	decf	arg2, F
	goto	media_read_loop

	
done_media_readloop:
	;; found the one we want, so we're all done!
	FINISH_READING_INLINE

	;; now set up the address for our next start-of-read.
	banksel mmc_next_block0
	movfw   mmc_next_block0
	movwf	mmc_block0
	movfw   mmc_next_block1
	movwf	mmc_block1
	movfw   mmc_next_block2
	movwf	mmc_block2
	movfw   mmc_next_block3
	movwf	mmc_block3
	banksel 0

	retlw	0x01		; media info read successfully
	
	
read_next_event:
	;; discard the 8-byte header (alarm start/end data)
	lcall	mmc_read_next	;discard 4 byte start
	lcall	mmc_read_next
	lcall	mmc_read_next
	lcall	mmc_read_next
	lcall	mmc_read_next	;discard 4 byte end
	lcall	mmc_read_next
	lcall	mmc_read_next
	lcall	mmc_read_next
continue_reading_events:	
	;; grab the event ID info and see whether or not it's already triggered
	fcall	mmc_read_next
	;; if the event ID is 0, we're done reading.
	addlw	0x00
	skpnz
	goto	finish_fail

	banksel	event_tmp_id	; store a copy for later
	movwf	event_tmp_id
	banksel	0

        fcall	eep_read
	banksel	event_tmp_val
	movwf	event_tmp_val	;hang on to the result for a moment
	banksel	0
	fcall	mmc_read_next
	banksel	event_tmp_bit
	movwf	event_tmp_bit
	
	;; If the event_tmp_id is zero, then we need to do something special:
	;; look in RAM instead of ROM.
	addlw	0x00
	skpnz
	goto	compare_event_in_ram
	
	andwf	event_tmp_val, W ;is that bit turned on?
	banksel	0
	skpz			;  (skip if not)
	goto	consume_event	;already played, so go check the next event

check_event_date:
	banksel	0		; one of the paths might have wrong bank sel'd
	
	;; Now. If it wasn't turned on, let's see if it's for *today*.
	;; presume that RTC_brst_rd is up to date...
;;; 	call	RTC_brst_rd	; read current date/time

	fcall	mmc_read_next	; get year (BCD)
	movwf	date_tmp
	xorlw	0xFF		; if it's 0xFF, it's "Every Year"...
	skpnz
	goto	compare_one_month ; compare it against a single month/day


	;; FIXME JORJ - REALLY READ THIS CODE FROM HERE IN! LOOKS WRONG
	movfw	date_tmp	; get it back
	subwf	time_yrs, W
	skpwle			; skip if time_yrs <= year stored on flash
	goto	consume_two

	movfw	date_tmp	; get it back again
	xorwf	time_yrs, W	; is it == this year?
	skpnz
	goto	compare_month

	lcall	mmc_read_next	; consume month
	fcall	mmc_read_next	; consume day
	goto	finish_compare_success ; and we're done testing; return success

compare_one_month:
	fcall	mmc_read_next	; get month (BCD)
	movwf	date_tmp
	xorwf	time_mon, W
	skpz
	goto	consume_one
compare_one_day:	
	fcall	mmc_read_next	; get day of month (BCD)
	xorwf	time_days, W
	skpz
	goto	consume_zero
	goto	finish_compare_success
	
compare_month:
	fcall	mmc_read_next	; get month (BCD)
	movwf	date_tmp
	subwf	time_mon, W
	skpwle
	goto	consume_one

	;; same as above: if the month has passed, we're done the comparison
	movfw	date_tmp
	xorwf	time_mon, W
	skpnz
	goto	compare_day

	fcall	mmc_read_next	; consume day
	goto	finish_compare_success ; and we're done testing; return success
	
compare_day:	
	fcall	mmc_read_next	; get day of month (BCD)
	subwf	time_days, W
	skpwle
	goto	consume_zero

finish_compare_success:	
	
	;; YES! Let's read the start/end addresses and store them. Then
	;; return that there's something available for today.
	fcall	mmc_read_next
	banksel	mmc_next_mediaid
	movwf	mmc_next_mediaid
	banksel	0

	;; finish reading this directory block
	lcall	finish_reading

	;; and then retrieve the block start/end for the media ID we found
	banksel	mmc_next_mediaid
	movfw	mmc_next_mediaid
	banksel	0
	
	lgoto	find_media_block ; will retlw 0x01 for us

consume_event:
	;; consume the date bytes (3), the address bytes, and then look @ next
	fcall	mmc_read_next
consume_two:	
	fcall	mmc_read_next
consume_one:	
	fcall	mmc_read_next
consume_zero:
	;; done consuming the date information. Need to consume the media ID
	;; and then loop to the next event
	fcall	mmc_read_next
	goto	continue_reading_events

finish_fail:
	lcall	finish_reading
	retlw	0x00

	;; If we found a bit pattern of 0x00, then we need to check the event
	;; in bank 3 ram instead. When done, we either go to consume_event
	;; (if the event has fired already) or we go to check_event_date (if
	;; the event hasn't happened yet and we need to see if it's for today).
compare_event_in_ram:
	;; If the event_np_flag is 0x01, then we want all transient events
	;; returned that are for today, regardless of whether or not they've
	;; been triggered today already.
	banksel	event_np_flag
	btfsc	event_np_flag, 0
	goto	check_event_date
	
	banksel	event_tmp_id
	movfw	event_tmp_id	; get back the old ID value
	movwf	FSR		;   put it into FSR
	bankisel	0x1A0	;   select FSR/INDF on bank 3
	movfw	INDF		;   get whatever's in that memory location

	addlw	0x00		;   and see if it's zero
	pagesel	check_event_date
	banksel	0
	bankisel 0
	skpnz
	goto	check_event_date ; == 0 means hasn't happened yet
	goto	consume_event	 ; != 0 means already fired


check_end_events:
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"bcd_math.asm crosses a page boundary"
	endif

	END
	