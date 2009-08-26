	extern	to_bcd
	extern	from_bcd
	include	"processor_def.inc"

INLINE_FROM_BCD	MACRO
	banksel	bcd_math_tmp
	movwf	bcd_math_tmp
	;; get high nibble in low, multiply by 10, add low nibble.
	swapf	bcd_math_tmp, W
	andlw	0x0F
	movwf	bcd_math_tmp2

	;; multiple by 10: shift left 2, add orig value (still in W),
	;; shift left 1 last time.
	clc
	rlf	bcd_math_tmp2, F
	clc
	rlf	bcd_math_tmp2, F
	addwf	bcd_math_tmp2, F
	clc
	rlf	bcd_math_tmp2, F

	;; get the low nibble of original value and add to new number
	movfw	bcd_math_tmp
	andlw	0x0F
	addwf	bcd_math_tmp2, W

	ENDM

INLINE_TO_BCD	MACRO
	LOCAL	to_bcd_loop
	LOCAL	end_bcd_loop
	movwf	bcd_math_tmp
	clrf	bcd_math_tmp2
to_bcd_loop:
	sublw	d'9'
	skpwgt
	goto	end_bcd_loop
	sublw	d'9'
	incf	bcd_math_tmp2, F
	addlw	-0x0A
	goto	to_bcd_loop
end_bcd_loop:
	sublw	d'9'
	movwf	bcd_math_tmp
	swapf	bcd_math_tmp2, W ; *= 16
	iorwf	bcd_math_tmp, W
	ENDM
	
	