;;; manually constructed map of all bootloader-used memory

#define crc_w 0x20
#define crc_i 0x21
#define crc_data 0x22
#define crc_prev_w 0x23

#define spi_befF 0x24
#define spi_addr3 0x25
#define spi_addr2 0x26
#define spi_addr1 0x27
#define spi_addr0 0x28
#define spi_befH 0x29
#define temp_spi 0x2a
#define temp_spi_2 0x2b
#define temp_spi_3 0x2c
#define mmc_init_timer 0x2d
#define mmc_init_timer2 0x2e
#define mmc_bytecount 0x2f
#define mmc_bytecount_h 0x30
#define spi_cmd_tmp 0x31
#define bb_spi_tmp 0x32
#define bb_spi_loopcnt 0x33

#define end_block0 0x34
#define end_block1 0x35
#define end_block2 0x36
#define end_block3 0x37
#define mmc_block0 0x38
#define mmc_block1 0x39
#define mmc_block2 0x3a
#define mmc_block3 0x3b
#define mmc_temp_0 0x3c
#define mmc_temp_1 0x3d
#define mmc_temp_2 0x3e
#define mmc_temp_3 0x3f

#define fpm_data_low_0 0x40
#define fpm_data_high_0 0x41
#define fpm_data_low_1 0x42
#define fpm_data_high_1 0x43
#define fpm_data_low_2 0x44
#define fpm_data_high_2 0x45
#define fpm_data_low_3 0x46
#define fpm_data_high_3 0x47

#define bl_tmp 0x48 ; used during errors

#define bl_byte1 0x70 ; used during 2-byte reads
#define bl_byte2 0x71 ; used during 2-byte reads
#define bl_sleep_ctr 0x72
#define bl_sd_state 0x73
 #define SD_INITIALIZED bl_sd_state, 0
 #define SD_NEEDSFLUSH bl_sd_state, 1
#define bl_serial_work_tmp 0x74
#define bl_serial_work_tmp2 0x75
#define bl_arg1 0x76
#define bl_arg2 0x77
#define bl_counter 0x78
#define bl_writectr_low 0x79
#define bl_writectr_high 0x7a
#define bl_sd_chksum_crc7 0x7b
#define bl_bytes_low 0x7c
#define bl_bytes_high 0x7d
#define bl_running_fwvers 0x7e
#define bl_sd_fwvers 0x7f ; persistent through bootloader process


