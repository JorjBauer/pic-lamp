	include "processor_def.inc"
	include "../main/constants.inc"
	include "bl_memory.inc"
	include "../main/common.inc"
	include "min_serial.inc"
#define HAVE_MMC_EXTERNS
	include	"min_sd_spi.inc"
	include "crc7.inc"
	
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
	
        errorlevel -306		; suppress warnings about pages
	
	;; this code does not need to live in any particular page.
	
;;; send an SPI command to a device. This only understands R1 commands,
;;; which expect 1 byte replies. It also correctly calculates CRCs.
spi_command:
	call	send_break
	
	lcall	crc7_init	
	movfw	spi_befF	; 0x40 | command
	lcall	crc7_addbyte
	PERFORM_SPI
	movfw	spi_addr3	; high bits
	lcall	crc7_addbyte
	PERFORM_SPI
	movfw	spi_addr2
	lcall	crc7_addbyte
	PERFORM_SPI
	movfw	spi_addr1
	lcall	crc7_addbyte
	PERFORM_SPI
	movfw	spi_addr0	; low bits
	lcall	crc7_addbyte 	; returns the byte that was passed in
	PERFORM_SPI
	movlw	1
	lcall	crc7_addbyte
	lcall	crc7_finish
	addlw	1

	movwf	bl_arg		;save it
	movlw	' '		;debug
	lcall	putch_usart	;debug
	movfw	spi_befF	;debug
	lcall	putch_hex_usart	;debug
	movfw	spi_addr3	;debug
	lcall	putch_hex_usart	;debug
	movfw	spi_addr2	;debug
	lcall	putch_hex_usart	;debug
	movfw	spi_addr1	;debug
	lcall	putch_hex_usart	;debug
	movfw	spi_addr0	;debug
	lcall	putch_hex_usart	;debug
	movfw	bl_arg		; [CRC]
	lcall	putch_hex_usart	; debug
	movlw	'='		;debug
	lcall	putch_usart	;debug
	movfw	bl_arg		;restore it

	PERFORM_SPI	; send CRC

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

debug_spi_result:
	movwf	bl_arg		;save it
	fcall	putch_hex_usart	;display it
	movfw	bl_arg		;restore it
	return

read_ocr:
	movlw	4
	movwf	spi_addr0
read_ocr_loop:	
	movlw	0xff
	PERFORM_SPI
	call	debug_spi_result
	decfsz	spi_addr0, F
	goto	read_ocr_loop
	clrf	spi_addr0
	return

send_break:	
	;; break between commands...
	bsf	SD_CS
	movlw	0xFF
	PERFORM_SPI
 	bcf	SD_CS
	return
	
;;; send the command given in W with a properly calculated checksum
send_init_cmd:
	movwf	spi_befF
	fcall	spi_command 	; pulls its value from spi_befF
	goto	debug_spi_result
	
;;; initialize an MMC for use.
mmc_init:
	movlw	d'16'		; repeat CMD0 up to 16 times before giving up
	movwf	mmc_init_timer2
	
repeat_cmd0:
	;; send 80 pulses without CS asserted
 	bsf	SD_CS		; CS is active-low. Disable CS.
	movlw	0x0B		; send an initial 10*8 = 80 clock pulses
	movwf	temp_spi_2
send_another_pulse:	
	movlw	0xFF
	PERFORM_SPI
	decfsz	temp_spi_2, F
	goto	send_another_pulse
	
 	bcf	SD_CS		; CS is active-low. Enable CS.
	;; wait 16 clock cycles (or more)
	movlw	0xff
	movwf	mmc_init_timer	; loop counter.
	decfsz	mmc_init_timer, F
	goto	$-1

	;; Time to actually send CMD0
	clrf	spi_addr3
	clrf	spi_addr2
	clrf	spi_addr1
	clrf	spi_addr0
	movlw	CMD0		; send CMD0
	call	send_init_cmd

	xorlw	0x01		; expect reply 0x01 on success
	skpnz
	goto	continue_mmc_init
	;; failed - retry and loop.
	decfsz	mmc_init_timer2, F
	goto	repeat_cmd0
	goto	mmc_init_failed1

continue_mmc_init:
	;; reset succeeded. Card is confirmed to be in idle mode.

	movlw	0x01
	movwf	spi_addr1
	movlw	0xAA
	movwf	spi_addr0
	movlw	0x40 | 0x08 ; CMD8, SEND_OP_COND
	call	send_init_cmd
	xorlw	0x01
	skpz
	goto	failed_cmd8
	
	;; Didn't fail? Then it's Ver 2.00 or later card, either
	;; standard capacity or high/extended capacity. Read OCR.
	call	read_ocr

	;; Determine if voltage range is acceptable, based on what was
	;; in OCR. (We skip this step here, and assume it's okay.)

	;; If we get here, we'll send ACMD41 with HCS=0 ("old" mode)
	
failed_cmd8:	
	clrf	spi_addr1
	clrf	spi_addr0

	;; Send App CMD 41 (which means sending CMD55 CMD41) to set up SD card
	
	;; loop until we get init, or time out (mmc_init_timer)
	clrf	mmc_init_timer
	clrf	mmc_init_timer+1
mmc_init_v2:
mmc_init_v2_loop:
	decfsz	mmc_init_timer, F
	goto	_mivl1
	decfsz	mmc_init_timer+1, F
	goto	_mivl1
 	goto	mmc_init_failed2	; loop expired.
_mivl1
	clrf	spi_addr3
	clrf	spi_addr2
	clrf	spi_addr1
	clrf	spi_addr0
	movlw	CMD55
	call	send_init_cmd
#if 0	
	xorlw	0x01		; still idle? Should be.
	skpz
	goto	mmc_init_v2_loop ;retry.
#endif

	;; followed by ACMD41
	clrf	spi_addr3
	clrf	spi_addr2
	clrf	spi_addr1
	clrf	spi_addr0
	movlw	0x40 | 0x29	; ACMD41 (0x29)
	call	send_init_cmd

	addlw	0
	skpz			; idle?
	goto	mmc_init_v2_loop ; yes, idle (or error). Continue looping

	;; card has left idle state.
#if 0
	;; next: check the voltage for the card w/ CMD58
	
	movlw	CMD58
	call	send_init_cmd
	; CMD58 is an R3 cmd. We need to read 4 extra bytes (since spi_command only handles R1 commands)
	call	debug_spi_result
	movlw	0xff
	PERFORM_SPI
	call	debug_spi_result
	movlw	0xff
	PERFORM_SPI		; theoretically, reply should be MSK_OCR_33 (0xC0) which means it's a 3.3v card

;;;  	xorlw	0xc0
;;;  	skpz
;;;  	goto	mmc_init_failed	; wrong voltage card inserted! Uh-oh...
	call	debug_spi_result
	movlw	0xff
	PERFORM_SPI
	call	debug_spi_result
	movlw	0xff
	PERFORM_SPI
	call	debug_spi_result
#endif	
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
	call	debug_spi_result ;debug

	bsf	SD_INITIALIZED
	bcf	SD_NEEDSFLUSH
	retlw	0x00
	
mmc_init_failed1:
	retlw	0xFF
mmc_init_failed2:
	retlw	0xFE
	
	
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
	movfw	mmc_block3
	movwf	mmc_temp_3
	movfw	mmc_block2
	movwf	mmc_temp_2
	movfw	mmc_block1
	movwf	mmc_temp_1
	movfw	mmc_block0
	movwf	mmc_temp_0

	btfss	SD_NEEDSFLUSH
	goto	flush_not_reqd

	FINISH_READING_INLINE

flush_not_reqd:
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
	movfw	mmc_temp_3
	movwf	spi_addr3	; high bits
	movfw	mmc_temp_2
	movwf	spi_addr2
	movfw	mmc_temp_1
	movwf	spi_addr1
	movfw	mmc_temp_0
	movwf	spi_addr0	; low bits
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
	skpnz
	retlw	0x00		; return success (note difference from maxi version of sd_spi.asm)
	
mmc_start_read_failed:
	movfw	spi_cmd_tmp
	return			; return the failure code in W (guaranteed non-zero)
	
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

	;; increment the page count.
	incf	mmc_block0, F	; mmc_block is in bank 1
	skpnz
	incf	mmc_block1, F	; mmc_block is in bank 1
	skpnz
	incf	mmc_block2, F
	skpnz
	incf	mmc_block3, F
done_mmc_read:
			; recover from mmc_block and end_block...
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

	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"sd_spi.asm crosses a page boundary"
	endif
	
	end
	