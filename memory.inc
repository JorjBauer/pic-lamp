	extern	init_memory

;;; This is a manual map of all file registers, so that we have control over
;;; the bank alignment. I wish the banks could be individually addressed
;;; (perhaps "udata_bank0") -- then each code chunk could define the page it
;;; wants to work in. But since that doesn't seem to exist, the next best way
;;; to handle the problem seems to be this.

;;; memory locations 0x20 - 0x3f (bank 0, not clear if we should use them)

#define RING_BUFFER 0x20  ; 16 bytes from 0x20 through 0x2F
#define RING_BUFFER_RDPTR 0x30 ; index for reading from the ring buffer
#define RING_BUFFER_WRPTR 0x31 ; index for writing to the ring buffer
#define RING_BUFFER_BYTES 0x32 ; number of bytes in the ring buffer

;;; ds1307-i2c.asm
#define time_secs 0x33	; must be the start of the time buffer! 7 bytes long.
#define time_mins 0x34
#define time_hrs 0x35
#define time_dow 0x36
#define time_days 0x37
#define time_mon 0x38
#define time_yrs 0x39

#define I2CTMP 0x3a
#define I2CCOUNT 0x3b
#define rtc_timer 0x3c
;;; serial meta-interface
#define command 0x3d
#define command_tmp 0x3e

;;; date_tmp is used during event date calculations.
#define date_tmp 0x3f

;;; general purpose registers from 0x40-0x6f (bank 0)
;;; main.asm
#define sd_buffer 0x40		; 2 bytes
#define sd_buffer2 0x41
#define sleep_ctr 0x42		; 3 bytes
#define sleep_ctr2 0x43		; 3 bytes
#define sleep_ctr3 0x44		; 3 bytes

;;; sd_spi.asm
#define spi_befF 0x45
#define spi_addr3 0x46
#define spi_addr2 0x47
#define spi_addr1 0x48
#define spi_addr0 0x49
#define spi_befH 0x4a
#define temp_spi 0x4b
#define temp_spi_2 0x4c
#define temp_spi_3 0x4d
#define mmc_init_timer 0x4e
#define mmc_init_timer2 0x4f
#define mmc_bytecount 0x50
#define mmc_bytecount_h 0x51
#define spi_cmd_tmp 0x52
;;; spi.asm
#define bb_spi_tmp 0x53
#define bb_spi_loopcnt 0x54

#define alarm_brightness_value 0x55
#define alarm_brightness_delay 0x56

#define maxm_temp 0x57
#define maxm_temp2 0x58

#define mmc_next_mediaid 0x59

#define event_np_flag 0x5a

#define need_reread_clock 0x5b
#define debug_1 0x5c
#define debug_2 0x5d

#define red_mood 0x5e
#define green_mood 0x5f
#define blue_mood 0x60
#define mood_flags 0x61
 #define RED_MOOD_DIR mood_flags,0
 #define GREEN_MOOD_DIR mood_flags,1
 #define BLUE_MOOD_DIR mood_flags, 2
 #define RED_MOOD_PEGGED mood_flags, 3
 #define BLUE_MOOD_PEGGED mood_flags, 4
 #define GREEN_MOOD_PEGGED mood_flags, 5
#define mood_delay 0x62

#define music_control 0x6d
 #define MUSIC_PLAYING music_control, 0
 #define MUSIC_DRAINING music_control, 1
 #define NEED_STARTPLAYING music_control, 2
 #define NEED_START_ALARM music_control, 3
 #define NEED_START_ALERT music_control, 4
 #define NEED_START_TIMEQUEUE music_control, 5
 #define MUSIC_NEEDS_STOPPING music_control, 6
 #define STOP_MUSIC_NOW music_control, 7
#define button_state 0x6e
 #define BUTTON_NEEDS_CLEARING button_state, 0
 #define BUTTON_HELD_ULTRA_LONG button_state, 1

;;; general purpose registers from 0xa0 - 0xef (bank 1)

;;; music
#define end_block0 0xa0
#define end_block1 0xa1
#define end_block2 0xa2
#define end_block3 0xa3
#define mmc_block0 0xa4
#define mmc_block1 0xa5
#define mmc_block2 0xa6
#define mmc_block3 0xa7
#define mmc_next_block0 0xa8
#define mmc_next_block1 0xa9
#define mmc_next_block2 0xaa
#define mmc_next_block3 0xab
#define event_tmp_id 0xac
#define event_tmp_val 0xad
#define event_tmp_bit 0xae
#define mmc_hit_block_end 0xb0

;;; serial timeout
#define serial_timeout_0 0xb3
#define serial_timeout_1 0xb4
#define serial_timeout_2 0xb5
;;; serial.asm
#define serial_work_tmp 0xb6
#define serial_work_tmp2 0xb7

;;; debounce delay
#define debounce_1 0xb8
#define debounce_2 0xb9
#define debounce_3 0xba
#define button_hold_tmr1 0xbb
#define button_hold_tmr2 0xbc
#define button_hold_tmr3 0xbd

;;; 83Hz timer counter
;;#define _83hz_counter	0xbe

;;; SD SPI temp variables
#define mmc_temp_0 0xbf
#define mmc_temp_1 0xc0
#define mmc_temp_2 0xc1
#define mmc_temp_3 0xc2

;;; eeprom code memory read/write variables
#define fpm_data_low_0 0xc3
#define fpm_data_high_0 0xc4
#define fpm_data_low_1 0xc5
#define fpm_data_high_1 0xc6
#define fpm_data_low_2 0xc7
#define fpm_data_high_2 0xc8
#define fpm_data_low_3 0xc9
#define fpm_data_high_3 0xca

#define play_time_tmp	      0xcb 
#define play_time_tmp2	      0xcc
#define PLAY_TIME_QUEUE_SIZE  0xcd
#define PLAY_TIME_QUEUE_PTR   0xce
#define PLAY_TIME_QUEUE_0     0xd0
#define PLAY_TIME_QUEUE_1     0xd1
#define PLAY_TIME_QUEUE_2     0xd2
#define PLAY_TIME_QUEUE_3     0xd3
#define PLAY_TIME_QUEUE_4     0xd4
#define PLAY_TIME_QUEUE_5     0xd5
#define PLAY_TIME_QUEUE_6     0xd6
#define PLAY_TIME_QUEUE_7     0xd7
#define PLAY_TIME_QUEUE_8     0xd8
#define PLAY_TIME_QUEUE_9     0xd9
#define PLAY_TIME_QUEUE_10    0xda
#define PLAY_TIME_QUEUE_11    0xdb
#define PLAY_TIME_QUEUE_12    0xdc
#define PLAY_TIME_QUEUE_13    0xdd
#define PLAY_TIME_QUEUE_14    0xde
#define PLAY_TIME_QUEUE_15    0xdf

;;; general purpose registers from 0x120 - 0x16f (bank 2)
;;; NOTE: can't get to these easily with FSR, w/o using IRP rather than RP[01]

;;; blink_led
#define blink_data 0x120
#define blink_ctr 0x121
#define blink_ctr2 0x122
#define blink_ctr3 0x123
#define blink_bitcnt 0x124

;;; general purpose registers from 0x1a0 - 0x1ef (bank 3)
;;; NOTE: can't get to these easily with FSR

;;; Shared memory from 0x70-0x7f across all pages
#define save_w 0x70
#define save_status 0x71
#define save_pclath 0x72
#define save_fsr 0x73

;;; SD card low-layer flags
#define sd_state 0x74
 #define SD_INITIALIZED sd_state, 0
 #define SD_NEEDSFLUSH sd_state, 1
 #define MOOD_LIGHT_NEEDS_STEPPING sd_state, 7 ; not SD related...
 #define MOOD_LIGHT_NEEDS_HANDLING sd_state, 6 ; ... same thing ...

;;; general arguments (used for eeprom, must be globally addressable)
#define arg1	      0x75
#define arg2	      0x76

#define set_time_mode 0x77
 #define SET_TIME_HOURS        set_time_mode, 0
 #define SET_TIME_TEN_MINUTES  set_time_mode, 1
 #define SET_TIME_ONES_MINUTES set_time_mode, 2
 #define SET_TIME_TENS_YEAR    set_time_mode, 3
 #define SET_TIME_ONES_YEAR    set_time_mode, 4
 #define SET_TIME_MONTH        set_time_mode, 5
 #define SET_TIME_DAY          set_time_mode, 6
 #define SET_TIME_DOW          set_time_mode, 7
#define set_alarm_mode 0x78
 #define SET_ALARM_HOURS        set_alarm_mode, 0
 #define SET_ALARM_TEN_MINUTES  set_alarm_mode, 1
 #define SET_ALARM_ONES_MINUTES set_alarm_mode, 2
 #define SET_ALARM_LAMP         set_alarm_mode, 3
#define bcd_math_tmp 0x79
#define bcd_math_tmp2 0x7a

;;; events
#define alarm_light_type 0x7b
 #define ALARM_LIGHT_BLUE alarm_light_type, 0
 #define ALARM_LIGHT_WHITE alarm_light_type, 1
 #define ALARM_LIGHT_DISABLED alarm_light_type, 2
 #define ALARM_LIGHT_INVALID  alarm_light_type, 3 ; used during set-mode
#define cur_lamp_mode     0x7c
#define desired_lamp_mode 0x7d
#define alarm_h	      0x7e
#define alarm_m	      0x7f
