	include "processor_def.inc"
	include "constants.inc"
	include "memory.inc"
	include "blink_led.inc"
	include "common.inc"
	include "serial.inc"
#define HAVE_MMC_EXTERNS
	include	"sd_spi.inc"
	
	GLOBAL	mmc_init
	GLOBAL	mmc_start_read
	GLOBAL	mmc_read_next
	GLOBAL	mmc_cmd12
	GLOBAL	finish_reading
	GLOBAL	spi_command
	
;;; memory is managed *manually* via memory.inc.
;;; Variables used for this function are:
;;;   spi_befF, spi_addr3, spi_addr2, spi_addr1, spi_addr0, spi_befH
;;;   temp_spi, temp_spi_2, temp_spi_3, mmc_init_timer[2], mmc_bytecount,
;;;   mmc_bytecount_h, spi_cmd_tmp

sd_spi	code

	CONSTANT	_block_start = $
check_start_sd_spi:	
	
	;; this code does not need to live in any particular page.

;;; send an SPI command to a device. This only understands R1 commands,
;;; which expect 1 byte replies.
spi_command:
	SEND_BREAK_INLINE

spi_command_without_break:	
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

receive_reply:	
	movlw	0xFF		; R1 reply byte
	PERFORM_SPI
	movwf	spi_cmd_tmp
	pagesel	receive_reply
	btfsc	spi_cmd_tmp, 7	;can't use btfsc on the W reg :(
	goto 	receive_reply	; retry, as long as the high bit is still set

	movfw	spi_cmd_tmp	; return the value last read
	addlw	0x00		; make sure Z is set appropriately
	return

;;; initialize an MMC for use.
mmc_init:
	;; send 80 pulses without CS asserted
 	bsf	SD_CS		; CS is active-low. Disable CS.
	movlw	0x0B		; send an initial 10*8 = 80 clock pulses
	movwf	temp_spi_2
send_another_pulse:	
	movlw	0xFF
	PERFORM_SPI
	decfsz	temp_spi_2, F
	goto	send_another_pulse
	
	movlw	0xff
	movwf	mmc_init_timer	; loop counter.
 	bcf	SD_CS		; CS is active-low. Enable CS.
	;; wait 16 clock cycles
	decfsz	mmc_init_timer, F
	goto	$-1

	;; send Command(0x40, 0, 0, 0x95) and expect to read a '1'.
	movlw	CMD0		; "reset" - put into idle state
	movwf	spi_befF
	clrf	spi_addr3	; low bits
	clrf	spi_addr2
	clrf	spi_addr1
	clrf	spi_addr0	; high bits
	movlw	0x95
	movwf	spi_befH	; 0x95 is the proper CRC for this packet (well, 0x94 crc | 0x01 stop bit)
	fcall	spi_command
	xorlw	0x01		; expect reply 0x01 on success
	skpz
	goto	mmc_init_failed1
	
	;; reset succeeded. Card is confirmed to be in idle mode.
	
	;; loop until we get init, or time out (mmc_init_timer)
	clrf	mmc_init_timer
	clrf	mmc_init_timer+1
mmc_init_v2:
	decfsz	mmc_init_timer, F
	goto	mmc_init_v2_loop
	decfsz	mmc_init_timer+1, F
	goto	mmc_init_v2_loop
 	goto	mmc_init_failed2	; loop expired.
	
mmc_init_v2_loop:
	movlw	CMD55
	movwf	spi_befF
	movlw	0xff
	movwf	spi_befH
	fcall	spi_command
	xorlw	0x01		; still idle? Should be.
	skpz
	goto	mmc_init_v2 ;retry.
	
	;; followed by ACMD41
	movlw	0x40 | 0x29	; ACMD41 (0x29)
	movwf	spi_befF
	fcall	spi_command
	skpz			; idle?
	goto	mmc_init_v2	; yes, idle (or error). Continue looping

	;; card has left idle state.

	;; next: check the voltage for the card w/ CMD58
	movlw	CMD58
	movwf	spi_befF
	fcall	spi_command	; CMD58 is an R3 cmd. We need to read 4 extra bytes (since spi_command only handles R1 commands)
	movlw	0xff
	PERFORM_SPI
	movlw	0xff
	PERFORM_SPI		; theoretically, reply should be MSK_OCR_33 (0xC0) which means it's a 3.3v card
;;;  	xorlw	0xc0
;;;  	skpz
;;;  	goto	mmc_init_failed	; wrong voltage card inserted! Uh-oh...
	movlw	0xff
	PERFORM_SPI
	movlw	0xff
	PERFORM_SPI
	
	;; next: set the blocksize to 512 bytes.
 	movlw	CMD16
 	movwf	spi_befF
	clrf	spi_addr0	; 512-byte blocks
 	movlw	0x02
 	movwf	spi_addr1
	clrf	spi_addr2
	clrf	spi_addr3
 	fcall	spi_command
	;; also not checking the return value here from CMD16

	bsf	SD_INITIALIZED
	bcf	SD_NEEDSFLUSH
	return
	
mmc_init_failed1:
	movlw	0xFF
	fcall	more_blinking
	return
mmc_init_failed2:
	movlw	0xFE
	fcall	more_blinking
	return
	
	
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
mmc_start_read:
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
	banksel	0

	btfss	SD_NEEDSFLUSH
	goto	flush_not_reqd

	FINISH_READING_INLINE

flush_not_reqd:	
 	bcf	SD_CS		; CS is active-low. Enable CS. Leave it on.

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
	movwf	arg1
continue_m:
	clc
	rlf	spi_addr0, F
	rlf	spi_addr1, F
	rlf	spi_addr2, F
	rlf	spi_addr3, F
	decfsz	arg1, F
	goto	continue_m

	movlw	0xE0		; placeholder CRC, also the right CRC for 0000, but unimportant
	movwf	spi_befH
	fcall	spi_command
	skpz
	goto	mmc_start_read_failed
	
	retlw	0x01		; return success

	
mmc_start_read_failed:
	;; if you want to see the error on the serial port, then call this.
#if 1
 	movfw	spi_cmd_tmp
 	fcall	putch_hex_usart
	movlw	'!'
	fcall	putch_usart
	movlw	'!'
	fcall	putch_usart
#endif
	
	;; An error occurred, so shut down music playing.
	banksel	music_control
	bsf	MUSIC_DRAINING
	bcf	MUSIC_PLAYING
	banksel	0
	retlw	0x00		; return failure
	
;;; read the next byte from the MMC card (following the CMD18).
mmc_read_next:
	;; if we're at the start of a page, we have to wait for "data ready".
	movfw	mmc_bytecount_h
	skpz
	goto	mmc_do_read
	movfw	mmc_bytecount
	skpz
	goto	mmc_do_read
mmc_wait_data:	
	;; it's the first byte of a new page. Wait for the 'ack'.
	movlw	0xFF
	PERFORM_SPI
	xorlw	0xFE
	skpz
	goto	mmc_wait_data	; data not ready yet; retry
	;; got the ACK. Go ahead and start reading the data.
	
mmc_do_read:
	movlw	0xFF
	PERFORM_SPI		; get the data byte.
	movwf	temp_spi_3

	;; clear the 'end of block' flag (used by higher layer code)
	banksel	mmc_hit_block_end
	clrf	mmc_hit_block_end
	banksel	0
	
	;;  if we're at the end of a page, we have to read/discard the CRC.
	incfsz	mmc_bytecount, F
	goto	done_mmc_read
	incf	mmc_bytecount_h, F
	btfss	mmc_bytecount_h, 1 ; if mmc_pagecount<hl> == 0x200, we're done
	goto	done_mmc_read
	;; reset the counter and read in the CRC16 (which we discard).
	clrf	mmc_bytecount_h
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI

	;; set 'end of block' flag (used by higher layer code)
	banksel	mmc_hit_block_end
	bsf	mmc_hit_block_end, 0
	banksel	0

	;; increment the page count.
	banksel	mmc_block0
	incf	mmc_block0, F	; mmc_block is in bank 1
	skpnz
	incf	mmc_block1, F	; mmc_block is in bank 1
	skpnz
	incf	mmc_block2, F
	skpnz
	incf	mmc_block3, F
done_mmc_read:
	banksel	0		; recover from mmc_block and end_block...
	movfw	temp_spi_3	; return the result we read earlier
	return

;;; mmc's CMD12 is a STOP_TRANSMISSION command. It's required after we start a
;;; multi-block read (using CMD18) - have to read all 512 bytes from a block,
;;; and then send a CMD12.
mmc_cmd12:
	movlw	d'12' | 0x40	 ; STOP_TRANSMISSION, CMD12
	movwf	spi_befF
	clrf	spi_addr3
	clrf	spi_addr2
	clrf	spi_addr1
	clrf	spi_addr0
	clrf	spi_befH

	SPI_COMMAND_INLINE

	;; FIXME: make this check the RIGHT VALUE INSTEAD
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI
	movlw	0xFF
	PERFORM_SPI

	;; once we've executed CMD12, we're clear (from an SD perspective).
	bcf	SD_NEEDSFLUSH
	
	;; if we were called from mmc_read_next, this will do the necessary
	;; cleanup. And if we weren't, it does a couple of unncessary (but
	;; benign) operations. And it saves us a stack call from within
	;; mmc_read_next, so it's a winner...
	goto	done_mmc_read

finish_reading:
	FINISH_READING_INLINE
	return

check_end_sd_spi:	
	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"sd_spi.asm crosses a page boundary"
	endif
	
	end
	