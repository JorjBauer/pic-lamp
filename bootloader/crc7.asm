	include	"../processor_def.inc"
	include "bl_memory.inc"
	include "../common.inc"
	
	GLOBAL	crc7_init
	GLOBAL	crc7_addbyte
	GLOBAL	crc7_finish

crc7	code

crc7_init:
	clrf	crc_w
	clrf	crc_prev_w
	return

crc7_addbyte:
	movwf	crc_data

	movlw	0x80
	movwf	crc_i
	
	;; crc = (crc << 1) | ((crc_data[j] >> i) & 1)
	;; if (crc & 0x80) crc ^= 0x89
	;; if (i--==0) { j++; i=7; }
crc7_loop:
	movfw	crc_w
	movwf	crc_prev_w	; for the last iteration, which doesn't do the last bit
	
	clrc			; crc <<= 1
	rlf	crc_w, F
	movfw	crc_data	; crc |= 1 if (crc_data & i)
	andwf	crc_i, W
	skpz
	bsf	crc_w, 0
	
	btfss	crc_w, 7	; if (crc & 0x80)
	goto	no_permutation
	movlw	0x89		;    crc ^= 0x89
	xorwf	crc_w, F

no_permutation:	
	clrc			; i >>= 1  //  move to next i value
	rrf	crc_i, F
	skpc			; and if i==0, we're done with this byte
	goto	crc7_loop

	movfw	crc_data	; return the byte that was passed in.
	return

crc7_finish:
	clrc
	rlf	crc_prev_w, W
	return
	
	end
	