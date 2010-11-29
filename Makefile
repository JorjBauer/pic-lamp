all:

main: 
	cd main && make

test:
	cd main && make test

clean:
	(cd main && make clean) ; (cd bootloader && make clean) ; (cd card-image-creator && make clean)
	rm -f *~

distclean: clean
	(cd card-image-creator && make distclean)

disassemble:
	cd main && make disassemble

disassemblebl:
	cd main && make disassemblebl

card:
	cd card-image-creator && make card

install:
	cd main && make install

installmain:
	cd main && make installmain
