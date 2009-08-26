	include "processor_def.inc"
#define HAVE_SPI_EXTERNS
	include "min_spi.inc"
	
	GLOBAL	init_spi
	GLOBAL	perform_spi

spi	CODE

	CONSTANT	_block_start = $
        errorlevel -306		; suppress warnings about pages
	
	;; this code does not need to live in any particular page.

init_spi:
;;;  set up built-in SPI interface
	banksel SSPSTAT
	bcf     SSPSTAT, SMP ; SPI input sample phase = 0 (sample @ middle)
	bcf     SSPSTAT, CKE ; SPI clock edge select = 0 (data xmit @ falling edge)
	banksel SSPCON
	bsf     SSPCON, CKP ; clock polarity = 1 (high value is passive)
	bcf     SSPCON, SSPM3 ; start off with the SPI bus in slow mode,
	bcf     SSPCON, SSPM2 ; until we've initialized the SD card.
	bsf     SSPCON, SSPM1 ; 3:0 = 0010 (master, clock=osc/64)
	bcf     SSPCON, SSPM0
	bsf     SSPCON, SSPEN ; turn on SSP. Right now!

	banksel	PORTA
	return

perform_spi:
	PERFORM_SPI_INLINE
	return
	
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"spi.asm crosses a page boundary"
	endif
	
	END
	
