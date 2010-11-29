How to build
------------

0. Prerequisites: 

 * gpasm & gplink, to build the PIC code
 * picp, to program a PIC (16F877a)
 * cc (or gcc), to compile the flash image creator
 * sox, to process audio clips for the flash image
 * make

Optional:
 * perl, pic-disassemble

1. Building

 From the top directory, you just need to use 'make'. This will do a
 'make flash', which will build the main program; then the bootloader;
 generate the composite PIC firmware from the main program and
 bootloader; build the flash image generation program; process the
 media clips; and finally, build the flash image.

2. Installing

 Set up serial port in main/Makefile. (Change the SERIAL definition.)
 Then you can deploy the built firmware to a connected PIC programmer
 using 'make install'.

3. Flash firmware

 The file 'card-image-creator/flash.img' needs to be written to a
 MicroSD card. Note that you'll have to overwrite the entire
 filesystem on the card; this project doesn't know anything about (for
 example) the FAT filesystem. It expects raw data.

 I accomplish this on a Mac by:
 * sticking the MicroSD card in a reader, and attaching it to my Mac;
 * making sure it's unmounted (using the Disk Utility) but not ejected;
 * finding its device name using command-I from the Disk Utility;
 * finally, 'sudo dd if=card-image-creator/flash.img of=/dev/diskXXX'
   where diskXXX is whatever was reported by the Disk Utility.

4. Updating deployed hardware

The flash image contains a version-stamped copy of the firmware. (The
version.pl script increments its build count by one for each 'make
flash'.) Once you've burned a PIC, you can update the code on that PIC
(the main code, that is; not the bootloader, which is protected from
this process) by sticking a versioned MicroSD card in the circuit. At
boot time it will detect that the version on the card doesn't match
the version it's programmed with, and it will update itself. (This
works to downgrade, too.)
