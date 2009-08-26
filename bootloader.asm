        include "processor_def.inc"
	include	"main.inc"
	
	GLOBAL	bootloader

        errorlevel -306		; suppress warnings about pages

;;; ************************************************************************
;;; * Dummy bootloader file
;;; *
;;; *  This is a dummy bootloader file. It does nothing but jump straight to
;;; *  the main entry point (0x100). It's used to reserve memory from 0x1b00
;;; *  through 0x1fff during linking of the main program, and doubles as a
;;; *  stand-in for the bootloader if you need to troubleshoot the main
;;; *  program without the bootloader in your way.
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
	dw	0x06

	;; The bootloader itself starts at 0x1e04.
	ORG	0x1e04

bootloader:
	;; This is a dummy method, to be replaced by the real bootloader.
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
	