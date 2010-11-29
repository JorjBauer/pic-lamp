	include	"processor_def.inc"
	include	"bl_memory.inc"
	include "../main/common.inc"
	include "min_serial.inc"
	
	GLOBAL	fpm_read
	GLOBAL	fpm_write

WRITE_ONE_BYTE	MACRO
	movfw	INDF
	movwf	EEDATA
	incf	FSR, F
	movfw	INDF
	movwf	EEDATH
	incf	FSR, F
	banksel	EECON1
	bsf	EECON1, EEPGD
	bsf	EECON1, WREN
	movlw	0x55		; start of required sequence
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf	EECON1, WR
	nop
	nop			; end of required sequence
	bcf	EECON1, WREN
	btfsc	EECON1, WR	; just to be safe, wait for write bit to clear
	goto	$-1
	bcf	STATUS, RP0	; bank 2
	ENDM
	
piceeprom	code

	CONSTANT	_block_start = $

        errorlevel -306		; suppress warnings about pages
	
;;; fpm_read: put address location in bl_arg1(high)/bl_arg2(low).
;;; results are left in EEDATH (high) and EEDATA (low).
fpm_read:
	banksel	bl_arg1
	movfw	bl_arg1
	banksel	EEADRH
	movwf	EEADRH
	banksel	bl_arg2
	movfw	bl_arg2
	banksel	EEADR
	movwf	EEADR
	banksel	EECON1
	bsf	EECON1, EEPGD
	bsf	EECON1, RD	; start of required sequence
	nop
	nop			; end required sequence
	banksel	0
	return

;;; fpm_write: write to flash program memory.
;;; uses bl_arg1(high)/bl_arg2(low) for address.
;;; uses fpm_data_low[0..3] and fpm_data_high[0..3] for data.
;;; MUST write four bytes at a time, per hardware spec. And the address
;;; must be aligned on a multiple of 4.
;;; Destroys FSR.
fpm_write:
	bcf	INTCON, GIE	; just in case. There are no interrupts in the bootloader anyway
	
	movfw	bl_arg1
	banksel	EEADRH
	movwf	EEADRH
	movfw	bl_arg2
	banksel	EEADR
	movwf	EEADR
	bankisel	fpm_data_low_0
	banksel	EEDATA		; EEDATA, EEDATH and EEADR are all in the same bank. EECON is *not*.
	movlw	fpm_data_low_0
	movwf	FSR
fpm_write_start:
	movlw	0x04
	movwf	0x72
fpm_write_next:	
	WRITE_ONE_BYTE
	incf	EEADR, F
	decfsz	0x72
	goto	fpm_write_next

	bankisel 0
	banksel	0
	return
	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"piceeprom.asm crosses a page boundary"
	endif
	
	END
	