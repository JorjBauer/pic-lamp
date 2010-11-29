;;; clock speed
#define CLOCK 20000000

;;; pin assignments:
;;;    D/A converter SPI bus
#define DA_CS	 	PORTD, 7
#define BB_SPI_CLK	PORTD, 6
#define BB_SPI_DO	PORTD, 5
#define LDAC_PIN 	PORTD, 4
;;;    LEDs
#define BLUE_LED	PORTE, 0
#define GREEN_LED	PORTE, 1
#define RED_LED		PORTE, 2
;;;    Other
#define BUTTON_PIN	PORTA, 3
 #define BUTTON_PORT	PORTA
#define AUDIO_ENABLE	PORTB, 3
 #define SWITCH_PORT	PORTC
#define SARAHS_ALARM_ENABLE	PORTC, 1
#define ALARM_ENABLE	PORTC, 0
#define SD_CS		PORTD, 2

#define BLINK_LED1	GREEN_LED
#define BLINK_LED2	BLUE_LED

;;; bit-banging I2C bus definitions
#define SDA PORTD, 0
#define SCL PORTD, 1
#define SDATRIS TRISD, 0
#define SCLTRIS TRISD, 1

;;; 1s are inputs. 0s are outputs.
#define TRISA_DATA b'00001001' ; A<0> is AD0. A<3> is button.
#define TRISB_DATA b'00000000' ;
#define TRISC_DATA b'10010011' ; C<7> RX. C<4> SDI. C<3> SCK. C<5> SDO. C<1> alarm enable, C<0> old alarm enable.
#define TRISD_DATA b'00000000' ; D<2> SD_CS
#define TRISE_DATA b'00000000' ; all outputs


;;; SD card command constants
#define CMD0    (0x40 | 0)
#define CMD1    (0x40 | 1)
#define CMD16   (0x40 | 0x10)
#define CMD17   (0x40 | 0x11)
#define CMD18   (0x40 | 0x12)
#define CMD55   (0x40 | 0x37)
#define CMD58   (0x40 | 0x3A)

;;; light modes
#define LIGHTS_OFF 0
#define LIGHTS_ON 1	; full on
#define LIGHTS_MOODY 2	; rotating colors
#define LIGHTS_ORGAN 3	; colors based on audio input
#define LIGHTS_ALARM 4	; slowly brightening
#define LIGHTS_ALERT 5	; fast red double-pulse to indicate a waiting event
#define LIGHTS_ALARMING 6 ; ALARM mode, after an alarm has reached playback mode
#define LIGHTS_ALERTING 7 ; ALERT mode, once it's acknowledged and starts playing
#define LIGHTS_SPEAKING 8 ; SPEAKING mode, where we play from the media queue
#define LIGHTS_SETTIME 9 ; setting the time/date
#define LIGHTS_SETALARM 10 ; setting the alarm time


;;; EEPROM memory locations. The first 16 bytes are available. The rest are
;;; used to store event-has-happened tags.
#define EEPROM_INIT_FLAG 0x00

;;; magic constant: if this is in the EEPROM_INIT_FLAG, then we've initialized
;;; the eeprom at least once.
#define EEPROM_INIT_MAGIC 0x42

;;; media playback constants. Note that there is only room for 64 media entries
;;; on the card, b/c we're using only one block to store the index start/stop
;;; data. 512 bytes in the block, 4 bytes for start, 4 bytes for end (and 
;;; 512/8 == 64) -- which means we have only ONE SPACE OPEN at the moment
#define IDX_0 0
#define IDX_1 1
#define IDX_2 2
#define IDX_3 3
#define IDX_4 4
#define IDX_5 5
#define IDX_6 6
#define IDX_7 7
#define IDX_8 8
#define IDX_9 9 
#define IDX_10 10
#define IDX_11 11
#define IDX_12 12
#define IDX_13 13
#define IDX_14 14
#define IDX_15 15
#define IDX_16 16
#define IDX_17 17
#define IDX_18 18
#define IDX_19 19
#define IDX_20 20
#define IDX_21 21 
#define IDX_22 22
#define IDX_23 23
#define IDX_30 24
#define IDX_40 25
#define IDX_50 26
#define IDX_60 27
#define IDX_70 28
#define IDX_80 29
#define IDX_90 30
#define IDX_HUNDREDHOURS 31
#define IDX_TIMEIS 32
#define IDX_SETALARMHOUR 33
#define IDX_SETALARM 34
#define IDX_TENSOFMINUTES 35
#define IDX_ONESOFMINUTES 36
#define IDX_SETTIMEHOUR 37
#define IDX_SETTIME 38
#define IDX_SETMONTH 39
#define IDX_SETDAY 40
#define IDX_SETDOW 41
#define IDX_SETTENSOFYEAR 42
#define IDX_SETONESOFYEAR 43
#define IDX_TIMESETTO 44
#define IDX_ALARMSETTO 45
#define IDX_JANUARY 46
#define IDX_FEBRUARY 47
#define IDX_MARCH 48
#define IDX_APRIL 49
#define IDX_MAY 50
#define IDX_JUNE 51
#define IDX_JULY 52
#define IDX_AUGUST 53
#define IDX_SEPTEMBER 54
#define IDX_OCTOBER 55
#define IDX_NOVEMBER 56
#define IDX_DECEMBER 57
#define IDX_SUNDAY 58
#define IDX_MONDAY 59
#define IDX_TUESDAY 60
#define IDX_WEDNESDAY 61
#define IDX_THURSDAY 62
#define IDX_FRIDAY 63
#define IDX_SATURDAY 64
#define IDX_ALARMLIGHT 65
#define IDX_ALARMSTARTSEARLY 66
#define IDX_ALARMSTARTSONTIME 67
#define IDX_ANDTODAYIS 68
#define IDX_BLUE 69
#define IDX_DEADAIR 70
#define IDX_DISABLED 71
#define IDX_OCLOCK 72
#define IDX_SET 73
#define IDX_SETYEAR 74
#define IDX_WHITE 75

;#define IDX_BIRTHDAY 76
;#define IDX_JAKES 77
;#define IDX_JORJS 78
;#define IDX_PAULS 79
;#define IDX_SARAHS 80
;#define IDX_SUES 81

