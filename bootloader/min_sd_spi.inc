#ifndef HAVE_MMC_EXTERNS
	extern	mmc_init
	extern	mmc_start_read
	extern	mmc_read_next
	extern	mmc_cmd12
	extern	finish_reading
	extern	spi_command
#else
	include	"min_spi.inc"
#endif
	
FINISH_READING_INLINE	MACRO
	LOCAL	finish_event_read
;;;  must continue reading until mmc_bytecount == 0x00 and
;;;  mmc_bytecount_h == 0x00. Then we must send a "stop" event.
finish_event_read:
        fcall   mmc_read_next
        movfw   mmc_bytecount
        skpz
        goto    finish_event_read
        movfw   mmc_bytecount_h
        skpz
        goto    finish_event_read
        fcall   mmc_cmd12 ; Did read 512 bytes; all done. send cmd12
	ENDM
	
;;; start read of bytes from the MMC. spi_addr[3:0] must have the page
;;; address. The page address would be:
;;;   unsigned long block_number = ...;
;;;   varl = ((block_number & 0x003F) << 9)
;;;   varh = ((block_number & 0xFFC0> >> 7)
;;;   spi_addr[3] = HIGH(varh)
;;;   spi_addr[2] = LOW(varh)
;;;   spi_addr[1] = HIGH(varl)
;;;   spi_addr[0] = 0
;;; ... That comes from mmc_block[0..3], which is shifted left 9 bits
;;;     to obtain a byte address.
MMC_START_READ_INLINE	MACRO
	LOCAL	flush_not_reqd
	LOCAL	continue_m
	LOCAL	foo
	;; If we need to finish reading, we'll have to store the mmc_block
	;; variables someplace first - they'll get trashed in the process
	;; of flushing!
	banksel	mmc_block3
	movfw	mmc_block3
	banksel	mmc_temp_3
	movwf	mmc_temp_3
	banksel	mmc_block2
	movfw	mmc_block2
	banksel	mmc_temp_2
	movwf	mmc_temp_2
	banksel	mmc_block1
	movfw	mmc_block1
	banksel	mmc_temp_1
	movwf	mmc_temp_1
	banksel	mmc_block0
	movfw	mmc_block0
	banksel	mmc_temp_0
	movwf	mmc_temp_0

	banksel	flush_not_reqd
	btfss	SD_NEEDSFLUSH
	goto	flush_not_reqd

	banksel	0
	FINISH_READING_INLINE

flush_not_reqd:	
	banksel	0
;;; 	bcf	SD_CS		; CS is active-low. Enable CS. Leave it on.

	clrf	mmc_bytecount
	clrf	mmc_bytecount_h
	movlw	CMD18	; "read multiple blocks" command (CMD18)
	movwf	spi_befF

	;; once we send CMD18, we have to follow up with CMD12 (flushing).
	bsf	SD_NEEDSFLUSH

	;; grab the starting address from mmc_block[0..3] and set up the spi
	;; command buffer appropriately. We need to take the block number
	;; and multiply it by 512 (shift it left 9 bytes), leaving mmc_block
	;; unaltered (and putting the final address in spi_addr[0..3]).
	banksel	mmc_temp_3
	movfw	mmc_temp_3
	banksel	spi_addr3	; high bits
	movwf	spi_addr3
	banksel	mmc_temp_2
	movfw	mmc_temp_2
	banksel	spi_addr2
	movwf	spi_addr2
	banksel	mmc_temp_1
	movfw	mmc_temp_1
	banksel	spi_addr1
	movwf	spi_addr1
	banksel	mmc_temp_0
	movfw	mmc_temp_0
	banksel	spi_addr0	; low bits
	movwf	spi_addr0
	;; now that spi_addr[0..3] is loaded, let's do the multiplication!
	movlw	0x09		; shift the 32-bit value left 9 bits (x512)
	movwf	bl_arg1
continue_m:
	clc
	rlf	spi_addr0, F
	rlf	spi_addr1, F
	rlf	spi_addr2, F
	rlf	spi_addr3, F
	decfsz	bl_arg1, F
	goto	continue_m

	movlw	0xE0		; placeholder CRC, also the right CRC for 0000, but unimportant
	movwf	spi_befH
	fcall	spi_command
	movlw	0x01		; assume success. movlw doesn't affect Z.
	skpnz
	goto	done

	;; An error occurred. Shut down music playing.
	banksel music_control
	bsf     MUSIC_DRAINING
	bcf     MUSIC_PLAYING
	banksel 0
        movlw	0x00
done:	
	ENDM

;;; send an SPI command to a device. This only understands R1 commands,
;;; which expect 1 byte replies.
SPI_COMMAND_INLINE MACRO
	LOCAL	rr
	movfw	spi_befF	; 0x40 | command
	PERFORM_SPI
	movfw	spi_addr3	; high bits
	PERFORM_SPI
	movfw	spi_addr2
	PERFORM_SPI
	movfw	spi_addr1
	PERFORM_SPI
	movfw	spi_addr0	; low bits
	PERFORM_SPI
	movfw	spi_befH	; CRC (even if CRCs are disabled; dummy value)
	PERFORM_SPI

rr:
	movlw	0xFF		; R1 reply byte
	PERFORM_SPI
	movwf	spi_cmd_tmp
	pagesel	rr
	btfsc	spi_cmd_tmp, 7	;can't use btfsc on the W reg :(
	goto 	rr	     	; retry, as long as the high bit is still set

	movfw	spi_cmd_tmp	; return the value last read
	addlw	0x00		; make sure Z is set appropriately
	ENDM
