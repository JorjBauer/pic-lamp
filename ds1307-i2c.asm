        include         "processor_def.inc"

        include         "common.inc"
	include		"constants.inc"
	include		"memory.inc"

	GLOBAL RTC_brst_rd
	GLOBAL RTC_brst_wr
	GLOBAL RTC_WrAlarm
	GLOBAL RTC_RdAlarm
	
ds1307i2c	CODE

	CONSTANT	_block_start = $
check_start_ds1307i2c:	
	;;  This code is completely self-contained. As long as it doesn't cross
	;;  a page boundary, it will be fine.

	include "i2c.inc"
	
RTC_brst_rd:
	;; jorj debugging: added nops. not sure it works without em
	;; debugging 2: replaced w/ goto$1 to test why the clock stopped
	;; working. Is it b/c 20MHz is too fast?
	goto	$+1
	goto	$+1
	goto	$+1
	goto	$+1
	goto	$+1
	goto	$+1
	goto	$+1
	goto	$+1
	;;jorj debug: set the rtc clock output so we can see it blink
;;;  write the configuration byte to enable the 1Hz pulse output
	I2C_START
	movlw   0xD0	; slave address + write
	call    write_I2C
	movlw   7
	call    write_I2C
	movlw   0x10	; % 00010000 == output, and 1Hz pulse
	call    write_I2C
	I2C_STOP
;;;  end jorj debug
	
	;; 
	I2C_START
	movlw	0D0h		; slave address + write
	call	write_I2C
	movlw	0		; set word address to seconds register
	call	write_I2C
	I2C_START
	movlw	0D1h		; slave address + read
	call	write_I2C
	call	read_I2C	; read the seconds data
	movwf	time_secs		; save it
	call	ack		;
	call	read_I2C	; and so on
	movwf	time_mins
	call	ack		;
	call	read_I2C
	movwf	time_hrs
	call	ack		;
	call	read_I2C
	movwf	time_dow
	call	ack		;
	call	read_I2C
	movwf	time_days
	call	ack		;
	call	read_I2C
	movwf	time_mon
	call	ack		;
	call	read_I2C
	movwf	time_yrs
	call	nack		;
	I2C_STOP
	return

RTC_brst_wr:
	I2C_START
	movlw	0D0h		; slave address + write
	call	write_I2C
	movlw	0		; set word address to seconds register
	call	write_I2C
	movf	time_secs, W
	call	write_I2C
	movf	time_mins, W
	call	write_I2C
	movf	time_hrs, W
	call	write_I2C
	movf	time_dow, W
	call	write_I2C
	movf	time_days, W
	call	write_I2C
	movf	time_mon, W
	call	write_I2C
	movf	time_yrs, W
	call	write_I2C
	I2C_STOP
	return

RTC_WrAlarm:
	I2C_START
	movlw	0D0h		; slave address + write
	call	write_I2C
	movlw	0x08		; set word address to first ram addr (0x08)
	call	write_I2C
	movfw	alarm_h
	call	write_I2C
	movfw	alarm_m
	call	write_I2C
	movfw	alarm_light_type
	call	write_I2C
	I2C_STOP
	return

RTC_RdAlarm:
	I2C_START
	movlw	0D0h		; slave address + write
	call	write_I2C
	movlw	0x08		; set word address to alarm time (RAM)
	call	write_I2C
	I2C_START
	movlw	0D1h		; slave address + read
	call	write_I2C
	call	read_I2C	; read the seconds data
	movwf	alarm_h		; save it
	call	ack		;
	call	read_I2C	; and so on
	movwf	alarm_m
	call	ack
	call	read_I2C
	movwf	alarm_light_type
	call	nack		; all done, so nack
	I2C_STOP
	return

check_end_ds1307i2c:
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"ds1307-i2c.asm crosses a page boundary"
	endif
	
	END
	