        include "../processor_def.inc"
	include	"bl_memory.inc"
	include	"min_serial.inc"
	include	"min_sd_spi.inc"
	include	"min_spi.inc"
	include	"../constants.inc"
	include	"../common.inc"
	include	"min_piceeprom.inc"
	include "crc7.inc"
	
#define normal_startup 0x0100
	
	GLOBAL	bootloader

        errorlevel -306		; suppress warnings about pages
	
	CODE

	ORG	0x1d00
;;; String data block...
bl_vers:
	da	"Btldr v"
	dw	0x0000
flash_v:	
        da      "Flashing v"
	dw	0x0000
was_0x:
	da	" (was 0x"
	dw	0x0000
end_0x:
	da	") 0x"
	dw	0x0000
flashed:
	da	"Flashed 0x"
	dw	0x0000
words:
	da	" words\r\n"
	dw	0x0000
nl:
	da	"\r\n"
	dw	0x0000
crcfailmsg:
	da	"CRC7 failure: 0x"
	dw	0x0000
initfailmsg:
	da	"SD init failed: 0x"
	dw	0x0000
startfailmsg:
	da	"SD start failed: 0x"
	dw	0x0000
	
	ORG	0x1e00
	;; Code version storage: 0x1e00 is the version of code we're running
	dw	0x00
	;; 0x1e01 is reserved
	dw	0x00
	;; 0x1e02 is the bootloader major version (v0.)
	dw	0x00
	;; 0x1e03 is the bootloader minor version (19)
	dw	0x13

	;; The bootloader itself starts at 0x1e04.
	ORG	0x1e04

bootloader:
	banksel	ADCON0
	movlw	b'01100000'	; AN0 is analog, others digital. Powered off.
	movwf	ADCON0
	banksel	ADCON1
	movlw	b'11001110'
	movwf	ADCON1
	banksel	TRISA
	movlw	TRISA_DATA
	movwf	TRISA
	banksel	TRISB
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
	
	banksel	PORTA
	bcf	AUDIO_ENABLE
	bsf	BLUE_LED
	bsf	RED_LED
	bsf	GREEN_LED

	banksel	0
	
;;; set up bit-banging spi interface (for D/A chip) and built-in (for SD card)
	lcall   init_spi
	
	bcf	RED_LED		;status update...
	
;;; set up serial interface
	lcall	init_serial

	PUTCH_CSTR_INLINE putch_bootloader_worker, bl_vers

;;; put the version # on the serial port. Read it from 0x1e0[23] of prog memory
	movlw	0x1e
	movwf	bl_arg1
	movlw	0x02
	movwf	bl_arg2
	lcall	fpm_read
	banksel	EEDATA
	movfw	EEDATA
	banksel	0
	lcall	putch_hex_usart
	movlw	'.'
	lcall	putch_usart
	incf	bl_arg2, F
	lcall	fpm_read
	banksel	EEDATA
	movfw	EEDATA
	banksel	0
	fcall	putch_hex_usart
	movlw	' '
	fcall	putch_usart
	
;;; set up SD card
	fcall	mmc_init
	;; did it succeed?
	xorlw	0x00		; success == 0x00.
	skpz
	goto	mmc_init_failed

#if 0
;;; move the SPI bus to super-fast speed (osc/4 instead of osc/64)
	banksel	SSPCON
	bcf	SSPCON, SSPM1
	banksel	0
#endif
	
;;; give the SD card a few seconds to start up. Note that the page must be
;;; properly set, since we use goto...
	pagesel	bootloader_delay
bootloader_delay:
	clrf	bl_sleep_ctr
	clrf	bl_sleep_ctr+1
	movlw	0x02		; was 0x02, which is enough for the mmc...
	movwf	bl_sleep_ctr+2	; ... but having serial issues, trying larger
	decfsz	bl_sleep_ctr, F	; ... 0x20 appears to be enough for serial,
	goto	$-1		; ... while 0x04 is not.
	decfsz	bl_sleep_ctr+1, F
	goto	$-3
	decfsz	bl_sleep_ctr+2, F
	goto	$-5

	bcf	GREEN_LED	;status update

	movlw   0x0A
	movwf   mmc_block0 ; start @ block #10 (the eleventh block)
	clrf    mmc_block1
	clrf    mmc_block2
	clrf    mmc_block3
	clrf    end_block0
	clrf    end_block1
	clrf    end_block2
	clrf    end_block3
	fcall   mmc_start_read
	xorlw   0x00    ; successful start-of-read?
	skpz
	goto	mmc_start_failed	; if we can't init, then bail

	;; check the version of code we're running, and the version on the
	;; SD card. If they're the same, do nothing. If they're not, then
	;; perform a flash upgrade...
	lcall	mmc_read_next
	movwf	bl_sd_fwvers
	fcall	putch_hex_usart	;debug
	
	movlw	0x1E		; read previous version from prog memory, @
	movwf	bl_arg1		; 0x1e high
	movlw	0x00		;  and 
	movwf	bl_arg2		; 0x00 low
	fcall	fpm_read
	banksel	EEDATA
	movfw	EEDATA
	banksel	0
	movwf	bl_running_fwvers
	fcall	putch_hex_usart	;debug
	movfw	bl_running_fwvers		;debug
	
	xorwf	bl_sd_fwvers, W		; is it the same as the one on the flash?
	skpnz
	goto	finish_bootloader ; already running this version! All done.

	
	;; double-check: was the version on the SD card 0x00? If so, no upgrade
	movfw	bl_sd_fwvers
	addlw	0x00
	skpnz
	goto	finish_bootloader ; no version on the SD card. All done.
	
	;; Flash upgrade time!
	bsf	RED_LED

	PUTCH_CSTR_INLINE putch_bootloader_worker, flash_v

	movfw	bl_sd_fwvers
	lcall	putch_hex_usart
	PUTCH_CSTR_INLINE putch_bootloader_worker, was_0x
	movfw	bl_running_fwvers
	lcall	putch_hex_usart
	PUTCH_CSTR_INLINE putch_bootloader_worker, end_0x
	
	lcall	mmc_read_next
	movwf	bl_bytes_high		; bootloader_bytes_high
	lcall	putch_hex_usart
	
	lcall	mmc_read_next
	movwf	bl_bytes_low		; bootloader_bytes_low
	lcall	putch_hex_usart
	
	fcall	mmc_read_next
	movwf	bl_sd_chksum_crc7		; bootloader_checksum_crc7
	btfsc	bl_sd_chksum_crc7, 0	; CRC7 should always have the low bit clear - if not, abandon
	goto	finish_bootloader
	
	lcall	crc7_init
	
	PUTCH_CSTR_INLINE putch_bootloader_worker, words

	movlw	0x04
	movwf	bl_writectr_low
	clrf	bl_writectr_high

bootstrap_loop:
#if 0
	;; print debugging output to serial port: address we're writing to
	movlw	' '
	lcall	putch_usart
	movfw	bl_writectr_high
	lcall	putch_hex_usart
	movfw	bl_writectr_low
	lcall	putch_hex_usart
	movlw	' '
	lcall	putch_usart
#endif
	
	;; read 4 bytes (b/c we have to write 4 bytes at a time)
	movlw	0x04
	movwf	bl_counter
	movlw	fpm_data_low_0
	movwf	FSR
	bankisel fpm_data_low_0
read_another_please:	
	lcall	mmc_read_next	; have to swap the byte-order, so read 2 bytes
	movwf	bl_byte1	; and store them in ram temporarily
	lcall	mmc_read_next
	movwf	bl_byte2

	movwf	INDF		; store byte2 first
	incf	FSR, F
	movfw	bl_byte1
	movwf	INDF		; store byte1 second
	incf	FSR, F

	;; add them to the CRC and print them for debugging
#if 0
	movfw	bl_byte2
	lcall	putch_hex_usart
#endif
	movfw	bl_byte2
	lcall	crc7_addbyte

#if 0
	movfw	bl_byte1
	lcall	putch_hex_usart
#endif
	movfw	bl_byte1
	lcall	crc7_addbyte

	pagesel	read_another_please
	decfsz	bl_counter
	goto	read_another_please

	;; flash those 4 words to the appropriate memory.
	movfw	bl_writectr_low
	movwf	bl_arg2
	movfw	bl_writectr_high
	movwf	bl_arg1
	fcall	fpm_write

	;; add 4 words to our number of words written counter
	movlw	0x04
	addwf	bl_writectr_low, F
	skpnz
	incf	bl_writectr_high, F

	movfw	bl_writectr_high	; cap bootloader_writectr_high at 0x1B
	xorlw	0x1b
	skpnz			; if == 0x1b, we're DONE for safety reasons...
	goto	finish_updating_bootloader
	xorlw	0x1b		; undo the xor damage
	movwf	bl_writectr_high

	;; flash lights while we flash program memory...
	btfss	bl_writectr_high, 2
	bsf	RED_LED
	btfss	bl_writectr_high, 2
	bcf	GREEN_LED
	btfsc	bl_writectr_high, 2
	bcf	RED_LED
	btfsc	bl_writectr_high, 2
	bsf	GREEN_LED
	
	;; are we at the end of our flash upgrade?
	;; test if bootloader_bytes != bootloader_writectr, goto bootstrap_loop
	movfw	bl_bytes_high
	xorwf	bl_writectr_high, W
	skpz
	goto	bootstrap_loop
	movfw	bl_bytes_low
	xorwf	bl_writectr_low, W
	skpz
	goto	bootstrap_loop

finish_updating_bootloader:
	;; show the # of words we wrote
	PUTCH_CSTR_INLINE putch_bootloader_worker, flashed
	movfw	bl_writectr_high
	lcall	putch_hex_usart
	movfw	bl_writectr_low
	lcall	putch_hex_usart
	PUTCH_CSTR_INLINE putch_bootloader_worker, words

	;; validate checksum. If it's not correct, don't update...
	lcall	crc7_finish
	xorwf	bl_sd_chksum_crc7
	skpz
	goto	bootloader_crc_failure
	
	movlw	0x1E
	movwf	bl_arg1
	movlw	0x00
	movwf	bl_arg2
	lcall	fpm_read
	banksel	EEDATH
	movfw	EEDATH
	banksel	fpm_data_high_0
	movwf	fpm_data_high_0
	banksel	EEDATA
	movfw	EEDATA
	banksel	fpm_data_low_0
	movwf	fpm_data_low_0

	incf	bl_arg2, F
	lcall	fpm_read
	banksel	EEDATH
	movfw	EEDATH
	banksel	fpm_data_high_1
	movwf	fpm_data_high_1
	banksel	EEDATA
	movfw	EEDATA
	banksel	fpm_data_low_1
	movwf	fpm_data_low_1

	incf	bl_arg2, F
	lcall	fpm_read
	banksel	EEDATH
	movfw	EEDATH
	banksel	fpm_data_high_2
	movwf	fpm_data_high_2
	banksel	EEDATA
	movfw	EEDATA
	banksel	fpm_data_low_2
	movwf	fpm_data_low_2

	incf	bl_arg2, F
	lcall	fpm_read
	banksel	EEDATH
	movfw	EEDATH
	banksel	fpm_data_high_3
	movwf	fpm_data_high_3
	banksel	EEDATA
	movfw	EEDATA
	banksel	fpm_data_low_3
	movwf	fpm_data_low_3

	clrf	bl_arg2		; low byte; go back to 0x1e00
	movfw	bl_sd_fwvers	; get the code version & put it into flash
	movwf	fpm_data_low_0
	lcall	fpm_write

finish_bootloader:
	PUTCH_CSTR_INLINE putch_bootloader_worker, nl
	
 	lcall	finish_reading

	lgoto	normal_startup
	pagesel	mmc_init_failed	; for debugging/disassembly purposes...

bootloader_crc_failure:
	PUTCH_CSTR_INLINE putch_bootloader_worker, crcfailmsg
	lcall	crc7_finish
	fcall	putch_hex_usart
	goto	finish_bootloader

mmc_init_failed:
	movwf	bl_tmp
	PUTCH_CSTR_INLINE putch_bootloader_worker, initfailmsg
	movfw	bl_tmp
	fcall	putch_hex_usart
	goto	finish_bootloader
mmc_start_failed:
	movwf	bl_tmp
	PUTCH_CSTR_INLINE putch_bootloader_worker, startfailmsg
	movfw	bl_tmp	; get it back, and print it
	fcall	putch_hex_usart
	goto	finish_bootloader
	
putch_bootloader_worker:
	PUTCH_CSTR_INLINEWKR

;;; This *must* fill to the end of the block (end 0x2000) or there's a
;;; possibility that the linker will place code after the bootloader. If
;;; that happens, we won't be able to flash-update it.

	if ( $ >= 0x2000 )
	ERROR	"Bootloader is too long"
	endif

	while ( $ < 0x2000 )
	dw	0x00
	endw
	
	END
	