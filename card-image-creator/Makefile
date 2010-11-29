all: card

card: create-flash version
	./create-flash

version:
	if [ ! -e "version-count" ]; then touch version-count; fi

create-flash: create-flash.o

clean:
	rm -f create-flash *~ *.o flash.img

distclean: clean
	rm -f version-count
