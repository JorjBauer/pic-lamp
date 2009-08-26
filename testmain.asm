	#include "processor_def.inc"

	#include "common.inc"
	#include "constants.inc"
	
	__CONFIG ( _CP_OFF & _DEBUG_OFF & _WRT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC )

_ResetVector	set	0x00
_InitVector	set	0x04

	code
	
	org	_ResetVector
	goto	Main

	org	_InitVector
	retfie

	org 0x05
Main:
	;; make all ports outputs.
	BANKSEL	TRISA
	clrf	TRISA
	clrf	TRISB
	clrf	TRISC
	clrf	TRISD

	banksel	PORTA
	movlw	0xFF
	movwf	PORTA
	movwf	PORTB
	movwf	PORTC
	movwf	PORTD
forever:
	goto	forever
	
	END
	