all: flash

flash: create-flash version
	if [ ! -d "cache" ]; then mkdir cache; fi
	(cd ../main && make firmware.bin)
	./create-flash

version:
	if [ ! -e "version-count" ]; then touch version-count; fi

create-flash: create-flash.o

clean:
	rm -f create-flash *~ *.o flash.img

distclean: clean
	rm -f version-count
	rm -rf cache
