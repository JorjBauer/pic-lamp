	include	"processor_def.inc"
	include	"constants.inc"
	include	"common.inc"
	include	"memory.inc"
	include	"sd_spi.inc"
	include	"spi.inc"
	include "events.inc"
	include "serial.inc"
	
	GLOBAL	start_playing
	GLOBAL	stop_playing
	GLOBAL	buffer_more_music
	GLOBAL	play_another_sample
	GLOBAL	init_media_queue
	
music	CODE

	CONSTANT	_block_start = $
check_start_music:

	

init_media_queue:	
        banksel PLAY_TIME_QUEUE_SIZE
	clrf    PLAY_TIME_QUEUE_SIZE
	movlw   PLAY_TIME_QUEUE_0
	movwf   PLAY_TIME_QUEUE_PTR
	movwf   FSR
	banksel	0
	return
	
stop_playing:
	;; If not playing, don't do anything.
	banksel	music_control
	btfss	MUSIC_NEEDS_STOPPING
	return

	;; If we did a start, then we need to finish the read.
	btfsc	MUSIC_NEEDS_STOPPING
	goto	not_finish_reading

	FINISH_READING_INLINE

not_finish_reading:	
	;; fixup the status flags...
	bcf	MUSIC_NEEDS_STOPPING
	bcf	MUSIC_PLAYING
	bcf	MUSIC_DRAINING

	;; if we're playing multiple samples from the media queue, then don't
	;; disable the audio amp. Otherwise, make sure we turn it off! This
	;; is sort of a hack, reaching into data from another layer that we
	;; probably shouldn't have access to. fixme?
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SPEAKING
	skpnz
	goto	continue_playqueue ; playing a queue - keep going
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SETTIME
	skpnz
	goto	continue_playqueue ; playing a queue - keep going
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SETALARM
	skpz
	goto	normal_stop	; not speaking so finish by shutting it down

continue_playqueue
	banksel	PLAY_TIME_QUEUE_SIZE
	movfw	PLAY_TIME_QUEUE_SIZE
	addlw	0x00
	skpnz
	goto	normal_stop	; no data left to play, so stop
	banksel	0
	return
	
normal_stop:
	banksel	0
	bcf	AUDIO_ENABLE	; disable audio amplifier
	return
	
start_playing:
	;; make sure we're not in the middle of another playback; if so, stop
	btfsc	MUSIC_NEEDS_STOPPING
	call	stop_playing
	
	;; initialize the ring buffer
	movlw   0x20
	movwf   RING_BUFFER_RDPTR
	movwf   RING_BUFFER_WRPTR
	clrf    RING_BUFFER_BYTES
	bcf	MUSIC_DRAINING

	;; turn on the playing bit to start actually playing
	bsf	MUSIC_PLAYING
	;; set that we're playing now, and will require a stop later
	bsf	MUSIC_NEEDS_STOPPING
	
	;; the start block is in mmc_block[0..3], and the end block is in
	;; end_block[0..3]. Those arguments are passed right in to
	;; mmc_start_read.
	fcall    mmc_start_read

	;; if an error occurred in mmc_start_read, then abort the attempt to
	;; start playing. Return code 0x01 is success...
	xorlw	0x01
	skpnz
	goto	continue_starting
	
	;; there was an initialization failure on the MMC card. Uh-oh.
	bcf	INTCON, GIE
	fcall	mmc_init
	bsf	INTCON, GIE
	;; FIXME: what to do??? Anything else??
	return

continue_starting:
	;; This lcall is technically not necessary most of the time.
	;; Testing whether or not it will prevent the stuttering I'm getting
	;; while setting alarms...
 	lcall	force_buffer

	;; enable the audio output amp
	bsf	AUDIO_ENABLE

	return
	
buffer_more_music:
	;; only play music if we're supposed to be...
	btfss	MUSIC_PLAYING
	return
	btfsc	MUSIC_DRAINING
	return
force_buffer:
	movfw	RING_BUFFER_BYTES
	sublw	0x0A		; only let the ring buffer fill up to 10 bytes-ish
	skpwle
	return			; ring buffer full; come back later
	
	movfw	RING_BUFFER_WRPTR
	movwf	FSR
	fcall	mmc_read_next	; read the first byte and store it
	movwf	INDF
	incf	RING_BUFFER_WRPTR, F
	incf	FSR, F
	fcall	mmc_read_next	; read the second byte and store it
	movwf	INDF
	incf	RING_BUFFER_WRPTR, F
	incf	FSR, F

	bcf	RING_BUFFER_WRPTR, 4 ; stay in 0x20-0x2F.

	;; increment the buffer full count
	incf	RING_BUFFER_BYTES, F
	incf	RING_BUFFER_BYTES, F

	;; see if we hit end-of-block while reading.
	banksel	mmc_hit_block_end ;non-zero if we hit end-of-block.
	movfw	mmc_hit_block_end
	addlw	0x00
	skpz
	goto	check_end_of_page
	banksel	0
	return
check_end_of_page:
	;; see if we hit the end of the block range we're supposed to be
	;; playing back.
	banksel	mmc_block3
        movfw   mmc_block3
	subwf   end_block3, W
	skpz
	goto	done_buffer
	movfw   mmc_block2
	subwf   end_block2, W
	skpz
	goto	done_buffer
	movfw   mmc_block1
	subwf   end_block1, W
	skpz
	goto	done_buffer
	movfw   mmc_block0
	subwf   end_block0, W
	skpz
	goto	done_buffer

	;; we're at the end-of-read for this music block: set that we're
	;; draining, and tell the SD card we're done (with CMD12).
        banksel music_control
	bsf     MUSIC_DRAINING
	banksel 0
	lgoto    mmc_cmd12
done_buffer:
	banksel	0
	return
	
;;; *
;;; *
	
play_another_sample:
	btfss	MUSIC_PLAYING
	return

	movfw	RING_BUFFER_BYTES
	skpnz
	return			; buffer underrun! Bail.
	movfw	RING_BUFFER_BYTES
	xorlw	0x01
	skpnz
	return			; only 1 byte? not enough.
	
	bcf     DA_CS	; and enable for the D/A converter

	movfw	RING_BUFFER_RDPTR
	movwf	FSR
	movfw	INDF
	fcall	bb_spi_send
	incf	FSR, F
	movfw	INDF
	fcall	bb_spi_send
	incf	RING_BUFFER_RDPTR, F
	incf	RING_BUFFER_RDPTR, F
	bcf	RING_BUFFER_RDPTR, 4 ; stay in 0x20 - 0x2F

	;; decrement available byte count by 2
	decf	RING_BUFFER_BYTES, F
	decf	RING_BUFFER_BYTES, F

	;; check if we're done playing this sample (if we're draining the
	;; queue and the queue is now empty, then stop playing).
        btfss   MUSIC_DRAINING
	goto	finish_sample

	movfw	RING_BUFFER_BYTES
	addlw	0x00		; moving into W doesn't affect Z?? docs say yes
	skpz
	goto	finish_sample

	;; Must be done playing! We've drained the buffer, so turn everything
	;; off now. Must stop everything before we start it back up again.
	;; BUT WE CAN'T DO IT DIRECTLY. This function is called from the
	;; interrupt handler, which is NOT allowed to touch the SD card (to
	;; avoid collisions when trying to access from multiple threads).
	bsf	STOP_MUSIC_NOW

	;; With this debugging statement here, the lamp appears to function
	;; normally. Without it, the lamp hangs after playing long recordings.
	;; Don't know why, but not debugging it before sarah leaves!
	movlw	'S'		;debug
	fcall	putch_usart	;debug
	
	;; If we were in an alarming mode, start playing the alarm over again.
	;; The user has to push the button to get out of alarm mode. Note that
	;; start_alarm_event has to read from the SD card, which will mean
	;; starting and stopping a read, which can't happen unless we really
	;; stopped reading. We're being called from the TMR0 interrupt, which
	;; means we have to be very careful about what's happening in the
	;; main execution thread...

	movfw	cur_lamp_mode
	xorlw	LIGHTS_ALARMING
	skpnz
	bsf	NEED_START_ALARM ; restart music (light already at full)

	;; If we were playing a media entry from the queue, then move
	;; to the next one in the queue.
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SPEAKING
	skpnz
	bsf	NEED_START_TIMEQUEUE ; tell the queue to start the next item
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SETTIME
	skpnz
	bsf	NEED_START_TIMEQUEUE ; tell the queue to start the next item
	movfw	cur_lamp_mode
	xorlw	LIGHTS_SETALARM
	skpnz
	bsf	NEED_START_TIMEQUEUE ; tell the queue to start the next item

	;; If we were playing an alert, it has completed successfully -
	;; set it as having played to completion. The event's id info should
	;; still be set properly, so we can just call set_event_happened.
	;; And if we get here and there *isn't* an alert playing, just stop.
	movfw	cur_lamp_mode
	xorlw	LIGHTS_ALERTING
	skpz
	goto	finish_sample

	fcall	set_event_happened
	;; And disable the alert light mode.
	movlw	LIGHTS_OFF
	movwf	desired_lamp_mode
	;; fall through

finish_sample:	
	;; finish playing the bytes
	bsf     DA_CS
	;; fall through
	
da_latch:	
	bcf     LDAC_PIN ; quick blip on the LDAC pin to latch the data
	nop			; not sure whether these nops are req'd or not
	nop
	nop
	bsf     LDAC_PIN
	return

check_end_music:	
	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"music.asm crosses a page boundary"
	endif
	
	END
	