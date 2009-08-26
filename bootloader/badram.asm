	include	"processor_def.inc"

	code

	org	0x0000
	lgoto	0x1e04
	org	0x0004
	retfie

	;; Fill up various memory locations with garbage so the linker
	;; will ignore 'em
	
        while ( $ < 0x0100 )
	dw      0x00
	endw

	org	0x0100
loop_forever:
	lgoto	loop_forever
	
        while ( $ < 0x0200 )
	dw      0x00
	endw
        while ( $ < 0x0300 )
	dw      0x00
	endw
        while ( $ < 0x0400 )
	dw      0x00
	endw
        while ( $ < 0x0500 )
	dw      0x00
	endw
        while ( $ < 0x0600 )
	dw      0x00
	endw
        while ( $ < 0x0700 )
	dw      0x00
	endw
        while ( $ < 0x0800 )
	dw      0x00
	endw
        while ( $ < 0x0900 )
	dw      0x00
	endw
        while ( $ < 0x0a00 )
	dw      0x00
	endw
        while ( $ < 0x0b00 )
	dw      0x00
	endw
        while ( $ < 0x0c00 )
	dw      0x00
	endw
        while ( $ < 0x0d00 )
	dw      0x00
	endw
        while ( $ < 0x0e00 )
	dw      0x00
	endw
        while ( $ < 0x0f00 )
	dw      0x00
	endw
        while ( $ < 0x1000 )
	dw      0x00
	endw
        while ( $ < 0x1100 )
	dw      0x00
	endw
        while ( $ < 0x1200 )
	dw      0x00
	endw
        while ( $ < 0x1300 )
	dw      0x00
	endw
        while ( $ < 0x1400 )
	dw      0x00
	endw
        while ( $ < 0x1500 )
	dw      0x00
	endw
        while ( $ < 0x1600 )
	dw      0x00
	endw
        while ( $ < 0x1700 )
	dw      0x00
	endw
        while ( $ < 0x1800 )
	dw      0x00
	endw
        while ( $ < 0x1900 )
	dw      0x00
	endw
        while ( $ < 0x1a00 )
	dw      0x00
	endw
        while ( $ < 0x1b00 )
	dw      0x00
	endw
	
	
	end
	