	EXTERN	init_spi
	EXTERN	bb_spi_send

;; anything that used to 'call spi' should now PERFORM_SPI instead, which
;; saves a layer of stack...

;;; SPI helper routines
;;; spi(VAL): transmit (VAL) on the SPI bus, and read the corresponding
;;; reply back. Takes VAL in W, and returns result in W.
;;; Destroys STATUS<RP0:RP1>.

PERFORM_SPI	MACRO
	LOCAL	dummy
	pagesel	dummy
        ;; put the data on the output buffer
        banksel SSPBUF
        movwf   SSPBUF
        ;; wait for the return value to fill up the buffer
        banksel SSPSTAT

dummy:	
        btfss   SSPSTAT, BF     ; wait for buffer-full indicator
	goto	$-1

        ;; grab the return value and return it
        banksel SSPBUF
        movfw   SSPBUF

        ;; return it, and put us back in bank 0 RAM too.
        banksel PORTA
	ENDM

