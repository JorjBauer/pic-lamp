#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw(:DEFAULT :seek);
use bigint lib => 'Calc';

# First 4 bytes: start/end of the alarm event.
# Following that are blocks:
#  -> 1 byte, 1 bitmask for the event;
#  -> 4 bytes, start block of sound;
#  -> 4 bytes, end block of sound.
# The last event is all 0s.
#
# Each block is 512 bytes long.
#
# Block 0 contains the directory for alarm events.
# Block 1 contains the directory of parts-of-time-speech.
# Block 2 contains the flash version, if any, that's on this card.
#   If there is a flash version, blocks 3+ might also contain flash data.
# All other blocks are data.

$|=1;

my $ofh;
open($ofh, ">output.img") || die;
my $mapfile;
open($mapfile, ">mapfile.dat") || die;

# Configurables
my $start_id = 0x10;
my $alarm_song = 'chicago.wav2.raw';
#my $alarm_song = 'jake-hello.wav.raw';
#my @songs = ( 'boogie.wav2.raw', 'whels.wav2.raw', 'yoyo.wav2.raw' );
my @songs = ( '1.wav.raw', '2.wav.raw', '3.wav.raw' );
my %songdata = ( 'boogie.wav2.raw' => { day => 19, 
					month => 4,
					year => 10 },
		 'whels.wav2.raw' => { day => 20,
				       month => 4,
				       year => 10 },
		 'yoyo.wav2.raw' => {day => 21,
				     month => 4,
				     year => 10 },
		 '1.wav.raw' => { day => 7, 
				  month => 5,
				  year => 9 },
		 '2.wav.raw' => { day => 8, 
				  month => 5,
				  year => 9 },
		 '3.wav.raw' => { day => 9,
				  month => 5,
				  year => 9 },
);

my @media = ( '0.wav.raw', 
	      '1.wav.raw', 
	      '2.wav.raw', 
	      '3.wav.raw', 
	      '4.wav.raw', 
	      '5.wav.raw', 
	      '6.wav.raw', 
	      '7.wav.raw', 
	      '8.wav.raw', 
	      '9.wav.raw', 
	      '10.wav.raw', 
	      '11.wav.raw', 
	      '12.wav.raw', 
	      '13.wav.raw', 
	      '14.wav.raw', 
	      '15.wav.raw', 
	      '16.wav.raw', 
	      '17.wav.raw', 
	      '18.wav.raw', 
	      '19.wav.raw', 
	      '20.wav.raw', 
	      '21.wav.raw', 
	      '22.wav.raw', 
	      '23.wav.raw', 
	      '30.wav.raw',
	      '40.wav.raw',
	      '50.wav.raw',
	      '60.wav.raw',
	      '70.wav.raw',
	      '80.wav.raw',
	      '90.wav.raw',
	      'hundredhours.wav.raw',
	      'timeis.wav.raw',
	      # Second set of media clips: time/alarm setting info
	      'setalarmhour.wav.raw',
	      'setalarmminute.wav.raw',
	      'settimehour.wav.raw',
	      'settimeminute.wav.raw',
	      'setmonth.wav.raw',
	      'setday.wav.raw',
	      'setdow.wav.raw',
	      'tensyears.wav.raw',
	      'onesyears.wav.raw',
	      'timesetto.wav.raw',
	      'alarmsetto.wav.raw',
	      'january.wav.raw',
	      'february.wav.raw',
	      'march.wav.raw',
	      'april.wav.raw',
	      'may.wav.raw',
	      'june.wav.raw',
	      'july.wav.raw',
	      'august.wav.raw',
	      'september.wav.raw',
	      'october.wav.raw',
	      'november.wav.raw',
	      'december.wav.raw',
	      'sunday.wav.raw',
	      'monday.wav.raw',
	      'tuesday.wav.raw',
	      'wednesday.wav.raw',
	      'thursday.wav.raw',
	      'friday.wav.raw',
	      'saturday.wav.raw'
 );
my @media_directory;
my $media_dir_pos = 0;

# end configurables

my @directory;

while ($#directory != 511) {
    push (@directory, 0);
}
while ($#media_directory != 511) {
    push (@media_directory, 0);
}

my $start_block = 33; # where media starts being encoded to.
print $mapfile "Block $start_block";

my (@encoding) = process_song($alarm_song);
print "Encoded length: " , $#encoding + 1, "\n";
my $directory_pos = 0;
$directory[$directory_pos++] = ($start_block >> 24) & 0xFF;
$directory[$directory_pos++] = ($start_block >> 16) & 0xFF;
$directory[$directory_pos++] = ($start_block >> 8) & 0xFF;
$directory[$directory_pos++] = ($start_block ) & 0xFF;
$start_block += ($#encoding + 1) / 512;
$directory[$directory_pos++] = ($start_block >> 24) & 0xFF;
$directory[$directory_pos++] = ($start_block >> 16) & 0xFF;
$directory[$directory_pos++] = ($start_block >> 8) & 0xFF;
$directory[$directory_pos++] = $start_block & 0xFF;
print "New start block: $start_block\n";
print $mapfile "Block $start_block";

# Dump the directory and alarm song to the output image.
foreach my $i (@directory) {
    print $ofh sprintf("%c", $i);
}
# Dump dummy space for blocks 1-32, which we'll skip so there's room for a 
# new firmware image...
foreach my $i (1..32) {
    foreach my $j (0..511) {
	print $ofh (sprintf "%c", 0);
    }
}

foreach my $i (@encoding) {
    print $ofh sprintf("%c", $i);
}
@encoding = undef;


# Now add events for some more songs. Start @ id #1; #0 is 
# reserved for "there are no more events"
my (@id) = ($start_id, 0x01); # EEPROM id, bit flag in that block

foreach my $song (@songs) {
    @encoding = process_song($song);
    print "Encoded length: " , $#encoding + 1, "\n";
    foreach my $i (@encoding) {
	print $ofh sprintf("%c", $i);
    }

    add_directory(\@directory, \$directory_pos, \@id, \$start_block, 
		  \@encoding,
		  to_bcd($songdata{$song}->{day}),
		  to_bcd($songdata{$song}->{month}),
		  to_bcd($songdata{$song}->{year}) );

    @encoding = undef;
    print "New start block: $start_block\n";
    print $mapfile "Block $start_block";

    $id[1] <<= 1;
    if ($id[1] >= 0x100) {
	$id[0]++;
	$id[1] = 1;
	print "Starting on ID byte $id[0]\n";
    }
}

# Now take each of the media files and dump 'em. Build the media directory.
foreach my $media (@media) {
    @encoding = process_song($media);
    print "Encodedmedia length: " , $#encoding + 1, "\n";
    foreach my $i (@encoding) {
	print $ofh sprintf("%c", $i);
    }

    add_media(\@media_directory, \$media_dir_pos, \$start_block, \@encoding);

    @encoding = undef;
    print $mapfile "Block $start_block";
}

print $mapfile "\n";
# Okay, all done adding - dump the final directory and media directory.
seek($ofh, 0, SEEK_SET);
foreach my $i (@directory) {
    print $ofh sprintf("%c", $i);
}
foreach my $i (@media_directory) {
    print $ofh sprintf("%c", $i);
}

embed_firmware($ofh);

close $ofh;
exit;

sub embed_firmware
{
    my ($ofh) = @_;
  # Now embed any firmware we have. Write it big-endian. The original file is,
  # of course, little-endian. So swap.
    seek($ofh, 2 * 512, SEEK_SET); # Firmware goes on page 2 (the third page).
    my $FIRMWARE_VERSION = 4; # FIXME
    print $ofh sprintf("%c", $FIRMWARE_VERSION);
    my $bytecount = 7680; # FIXME: make more dynamic somehow?
    print $ofh sprintf("%c%c", int($bytecount/256), $bytecount%256);
    print "writing firmware... ";
    my $fw;
    open($fw, 'firmware.dat') || die;
    while (1) {
	my $b;
	my $size = sysread($fw, $b, 1024*1024);
	(print "\n" && last)
	    if ($size == 0);
	print ".";
	
	# the raw data is low byte first, of course. Grr.
	my (@a) = unpack('v*', $b);
	foreach my $a (@a) {
	    print $ofh sprintf("%c%c", int($a/256), $a%256);
	}
    }
    close $fw;
}

sub to_bcd {
    my ($val) = @_;

    # Convert from decimal to BCD. Assume it's < 100 (Decimal).
    return (int( $val / 10 ) * 16) + ($val % 10);
}

sub add_media {
    my ($dir, $dpos, $startb, $enc) = @_;

    my @e = @$enc;
    $dir->[$$dpos++] = ($$startb >> 24) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 16) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 8) & 0xFF;
    $dir->[$$dpos++] = ($$startb) & 0xFF;
    $$startb += ($#e + 1) / 512;
    $dir->[$$dpos++] = ($$startb >> 24) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 16) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 8) & 0xFF;
    $dir->[$$dpos++] = $$startb & 0xFF;
}

sub add_directory {
    my ($dir, $dpos, $id, $startb, $enc, $start_day, $start_month, $start_year) = @_;

    my @e = @$enc;

    $dir->[$$dpos++] = $id->[0];
    $dir->[$$dpos++] = $id->[1];
    $dir->[$$dpos++] = $start_year;
    $dir->[$$dpos++] = $start_month;
    $dir->[$$dpos++] = $start_day;
    $dir->[$$dpos++] = ($$startb >> 24) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 16) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 8) & 0xFF;
    $dir->[$$dpos++] = ($$startb) & 0xFF;
    $$startb += ($#e + 1) / 512;
    $dir->[$$dpos++] = ($$startb >> 24) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 16) & 0xFF;
    $dir->[$$dpos++] = ($$startb >> 8) & 0xFF;
    $dir->[$$dpos++] = $$startb & 0xFF;
}

sub process_song {
    my ($fn) = @_;

    print "Processing $fn\n";
    print $mapfile ": $fn\n";

    my $fh;
    open($fh, $fn) || die;

    my @ret;
    
    while (1) {
	my $b;
	my $size = sysread($fh, $b, 1024*1024);
	(print "\n" && last)
	    if ($size == 0);

	print ".";

	# the raw data is low byte first, of course. Grr.
	my (@a) = unpack('v*', $b);
#	print "have ", $#a + 1, " bytes\n";

	foreach my $a (@a) {
	    # Drop 4 bits off the top.
	    $a >>= 4;
	    
	    # Add the D/A header (%0011xxxx).
	    $a |= 0x3000;
	    
	    # Save the new value in big-endian order.
	    push (@ret, unpack('C*', pack('n', $a)));
	}
    }

    print "padding $fn\n";

    while (($#ret + 1) % 512) {
	# SPI device ID header (%0011) and a median PWM value (%1000...).
	push(@ret, 0x38, 0x00);
    }

    return @ret;
}

