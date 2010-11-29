	include	"processor_def.inc"
	include	"common.inc"
	include "memory.inc"
	
	GLOBAL	to_bcd
	GLOBAL	from_bcd

bcd_math	code

	CONSTANT	_block_start = $
check_start_bcd_math:	
	
;;; ************************************************************************
;;; * from_bcd:
;;; *   convert value in W from BCD to binary. Return it in W.
;;; ************************************************************************
	
from_bcd:
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
	
	return

;;; ************************************************************************
;;; to_bcd:
;;;   take value in W and convert from binary to BCD.
;;; ************************************************************************
to_bcd:
	movwf	bcd_math_tmp
	clrf	bcd_math_tmp2	; result goes here

	;; 'W' contains the value. Divide-by-10 through successive subtraction
to_bcd_loop:	
	sublw	d'9'		; loop as long as the value is >= 10.
	skpwgt
	goto	end_bcd_loop
	sublw	d'9'		; undo what we did to the W register...
	incf	bcd_math_tmp2, F ; add 1 to the result...
	addlw	-0x0A		; add -10 (aka "subtract 10") to our value...
	goto	to_bcd_loop	; and loop until we're done

end_bcd_loop:
	;; bcd_math_tmp2 now contains the answer, and W contains 9 - remainder.
	;; convert those numbers to BCD.
	sublw	d'9'		; get back our remainder from W
	movwf	bcd_math_tmp	; use this memory location for the final answer

	swapf	bcd_math_tmp2, W ; tens, *= 16
	iorwf	bcd_math_tmp, W

	;; final BCD answer is now in W.
	return

check_end_bcd_math:	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"bcd_math.asm crosses a page boundary"
	endif
	
	END
	