	include	"processor_def.inc"

	GLOBAL	putch_usart
	GLOBAL	putch_hex_usart
	GLOBAL	putch_BCD_usart
	GLOBAL	getch_usart
	GLOBAL	getch_usart_timeout
	GLOBAL	init_serial
	GLOBAL	putch_cstr_worker

dummy_serial	code
	
putch_usart:
putch_hex_usart:
putch_BCD_usart:
getch_usart:
getch_usart_timeout:
putch_cstr_worker:	
	return

init_serial:
	bcf	TXSTA, TXEN	;disable TX
	bcf	RCSTA, SPEN	;disable serial usart
	return
	
	END
