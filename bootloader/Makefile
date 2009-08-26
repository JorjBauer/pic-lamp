SCRIPT = /usr/local/share/gputils/lkr/16f877a.lkr
OBJECTS = min_piceeprom.o min_serial.o min_spi.o min_sd_spi.o badram.o crc7.o

all:bootloader.hex

bootloader.hex: $(OBJECTS) bootloader.o $(SCRIPT)
	gplink --map -c -s $(SCRIPT) -o bootloader.hex $(OBJECTS) bootloader.o

%.o:%.asm
	gpasm -c -w2 $<

clean:
	rm -f *~ *.o *.lst *.map *.hex *.cod *.cof memory.hint main.gif
