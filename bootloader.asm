        include "processor_def.inc"
	include	"main.inc"
	include "constants.inc"
	include "memory.inc"
	include "serial.inc"
	include "spi.inc"
	
	GLOBAL	bootloader

        errorlevel -306		; suppress warnings about pages

;;; ************************************************************************
;;; * Dummy bootloader file
;;; *
;;; *  This is a dummy bootloader file. It does some basic initialization
;;; *  that the "real" bootloader would do, and then jumps straight to the 
;;; *  main entry point (0x100). It also reserves memory from 0x1b00 through
;;; *  0x1fff during linking of the main program, so that the main app doesn't
;;; *  reserve any of the bootloader's space during its own linking.
;;; *
;;; *  This also aids in stack depth analysis. The stack depth of the
;;; *  bootloader and main program can be tested independently.
;;; ************************************************************************

	CODE

	ORG	0x1b00
	while ( $ < 0x1c00 )
	dw	0x00
	endw
	while ( $ < 0x1d00 )
	dw	0x00
	endw
	while ( $ < 0x1e00 )
	dw	0x00
	endw
	
	ORG	0x1e00
	;; Code version storage: 0x1e00 is the version of code we're running
	dw	0x00
	;; 0x1e01 is reserved
	dw	0x00
	;; 0x1e02 is the bootloader major version
	dw	0x00
	;; 0x1e03 is the bootloader minor version
	dw	0x00

	;; The bootloader itself starts at 0x1e04.
	ORG	0x1e04

bootloader:
	;; This is a dummy method, to be replaced by the real bootloader as a 
	;; post-linking step.

        banksel ADCON0
	movlw   b'01100000' 	; AN0 is analog, others digital. Powered off.
	movwf   ADCON0
	banksel ADCON1
	movlw   b'11001110'
	movwf   ADCON1
	
        banksel TRISA
	movlw   TRISA_DATA
	movwf   TRISA
	banksel TRISB
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
	banksel 0

	lcall	init_memory
	lcall	init_spi
	lcall	init_serial
	
	lgoto	normal_startup


	;; This is filler, so that the bootloader memory isn't used by
	;; any "real" code...

	while ( $ < 0x1f00 )
	dw	0x00
	endw
	while ( $ < 0x2000 )
	dw	0x00
	endw
	
	END
	