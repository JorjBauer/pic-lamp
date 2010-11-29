	#include "processor_def.inc"
	#include "constants.inc"
	#include "memory.inc"
	
	GLOBAL blink_led
	GLOBAL more_blinking

;;; memory is managed *manually* via memory.inc. Variables used:
;;; blink_ctr[3], blink_bitcnt, blink_data
	
	errorlevel -306			; suppress warnings about pages
	
blinkled	code

        CONSTANT        _block_start = $
check_start_blinkled:	
	;; This code is completely self-contained. As long as it doesn't cross
	;; a page boundary, it will be fine. It can live in any page.


;;; blink 2 leds. One blinks on for every bit, and the other only blinks on
;;; for bits that are set (in the W register). Starts with the high bit.

;;; ************************************************************************
;;; * blink_led:
;;; *
;;; *  Input: W = bit pattern to blink
;;; *
;;; * Blinks a pair of LEDs. One blinks each of 8 times. The other blinks
;;; * only when a corresponding bit of the input bit pattern (high bit first)
;;; * is '1'. So for 0x10, one LED blinks 8 times while the other blinks 1,
;;; * and is then off for the corresponding 7.
;;; ************************************************************************
	
blink_led:
	banksel	blink_data
	movwf   blink_data
	
repeat_led:
	banksel	PORTA
	bcf	BLINK_LED1
 	bcf	BLINK_LED2

	banksel	blink_bitcnt
	movlw	0x08
	movwf	blink_bitcnt

	clrf	blink_ctr	; delay counter
	clrf	blink_ctr2	; delay counter 2

	;; blink for the 8 bits.
repeat_blink:
	banksel	PORTA
	bcf	BLINK_LED1	; assume led1 will be off
 	bsf	BLINK_LED2	; led2 is always on

	banksel	blink_data
	rlf	blink_data, F
	banksel	PORTA
	btfsc	STATUS, C
	bsf     BLINK_LED1
	movlw   0x04
	banksel	blink_ctr3
	movwf   blink_ctr3
	decfsz  blink_ctr, F
	goto    $-1
	decfsz  blink_ctr2, F
	goto    $-3
	decfsz  blink_ctr3, F
	goto    $-5
;;;  both off for a cycle...
	banksel	PORTA
	bcf     BLINK_LED1
 	bcf     BLINK_LED2
	movlw   0x0c	; delay timer
	banksel	blink_ctr3
	movwf   blink_ctr3
	decfsz  blink_ctr, F
	goto    $-1
	decfsz  blink_ctr2, F
	goto    $-3
	decfsz  blink_ctr3, F
	goto    $-5

	decfsz  blink_bitcnt, F
	goto    repeat_blink
	
done_led:
	banksel	0
	return

;;; ************************************************************************
;;; * more_blinking:
;;; *
;;; *   Input: W = bit pattern (same as blink_led)
;;; *
;;; * This is just blinkd_led with a pause before it. This is intended to be
;;; * called right after blink_led, in situations where you want to repeat.
;;; ************************************************************************

more_blinking:
	banksel	blink_data
	movwf	blink_data
	movlw   0x20	; delay timer
	movwf   blink_ctr3
	decfsz  blink_ctr, F
	goto    $-1
	decfsz  blink_ctr2, F
	goto    $-3
	decfsz  blink_ctr3, F
	goto    $-5
	movfw   blink_data
	goto    blink_led

check_end_blinkled:
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"blink_led.asm crosses a page boundary"
	endif
	
	end
	