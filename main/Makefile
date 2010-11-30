SCRIPT = /usr/local/share/gputils/lkr/16f877a.lkr
OBJECTS = spi.o sd_spi.o memory.o mood_lights.o ds1307-i2c.o blink_led.o music.o piceeprom.o events.o button.o bcd_math.o bootloader.o maxm.o

#CFLAGS = -DDISABLE_SERIAL
#OBJECTS += dummy-serial.o
OBJECTS += serial.o
#SERIAL = /dev/tty.KeySerial1
SERIAL = `ls /dev/tty.PL2303-* 2>/dev/null|head -1`

all:main.hex

main.hex: $(OBJECTS) main.o $(SCRIPT)
	gplink --map -c -s $(SCRIPT) -o main.hex $(OBJECTS) main.o

%.o:%.asm
	gpasm $(CFLAGS) -c -w2 $<

clean:
	rm -f *~ *.o *.lst *.map *.hex *.cod *.cof memory.hint main.gif *.bin

test.hex: testmain.o
	gplink --map -c -s $(SCRIPT) -o test.hex testmain.o

test: test.hex
	if [ -e "$(SERIAL)" ]; then picp $(SERIAL) 16f877a -ef && picp $(SERIAL) 16f877a -wc `../util/perl-flags-generator test.hex` -s -wp test.hex ; else echo "Serial port not found" ; fi

memory.hint:
	../util/build-hints.pl > memory.hint

disassemble: main.hex memory.hint
	pic-disassemble -d -D 5 -a -s -I .string -S dummy:_\.org:check_start:check_end:^_ -i main.hex -m main.map -r memory.hint -g main.gif

disassemblebl: bootfile.hex memory.hint
	pic-disassemble -d -D 8 -a -s -I .string -S dummy:_\.org:check_start:check_end:^_ -i bootfile.hex -m main.map:../bootloader/bootloader.map -r memory.hint -g main.gif

firmware.bin: bootfile.hex
	../util/extract-firmware < bootfile.hex > firmware.bin

bootfile.hex: main.hex
	cd ../bootloader && make clean && make && cd ../main && ../util/create-bootfile

install: main.hex bootfile.hex
	if [ -e "$(SERIAL)" ]; then picp $(SERIAL) 16f877a -ef && picp $(SERIAL) 16f877a -wc `../util/perl-flags-generator main.hex` -s -wp bootfile.hex ; else echo "Serial port not found" ; fi

installmain: main.hex
	if [ -e "($SERIAL)" ]; then picp $(SERIAL) 16f877a -ef && picp $(SERIAL) 16f877a -wc `../util/perl-flags-generator main.hex` -s -wp main.hex ; else echo "Serial port not found" ; fi

visual: main.hex
	../util/visual-memory-map.pl < main.hex
