#!/usr/bin/perl

use strict;
use warnings;
use Device::SerialPort;
use Fcntl;
use Carp;

$|=1;

my $dev = "/dev/tty.usbserial";
#my $dev = "/dev/tty.KeySerial1";

# Set up the serial port
my $quiet = 1;
my $port = Device::SerialPort->new($dev, $quiet, undef)
    || die "Unable to open serial port";
$port->user_msg(1);
$port->error_msg(1);
$port->databits(8);
$port->baudrate(9600);
$port->parity("none");
$port->stopbits(1);
$port->handshake("none");
$port->reset_error();

my $baud = $port->baudrate;
my $parity = $port->parity;
my $data = $port->databits;
my $stop = $port->stopbits;
my $hshake = $port->handshake;
print "$baud ${data}/${parity}/${stop} handshake: $hshake\n";

$port->purge_all();

do_getdate($port);

# Set to current time/date (from local computer time)
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
do_setdate( $port, $mon+1, $mday, $year % 100, $wday, $hour, $min, $sec );
do_setalarm($port, $hour, $min+1);
do_getdate($port);
exit;

my %lamp_modes = ( 0 => 'LIGHTS_OFF',
		   1 => 'LIGHTS_ON',
		   2 => 'LIGHTS_MOODY',
		   3 => 'LIGHTS_ORGAN',
		   4 => 'LIGHTS_ALARM',
		   5 => 'LIGHTS_ALERT',
    );

do_setlamp($port, 2);
#foreach my $i (1..5) {
#    print "Setting lamp mode $lamp_modes{$i} ($i)\n";
#    do_setlamp($port, $i);
#    sleep(15);
#}

#print "Going into the alarm state and staying there for 23 minutes\n";
#do_setlamp($port, 4);
#foreach my $i (1..23) {
#    sleep(60);
#    print "$i minute(s) elapsed\n";
#}

#print "turning off lamps\n";
#do_setlamp($port, 0);

#do_clearhistory($port);
#do_history($port);

#do_play($port, 0, 66607);

do_getdate($port);
do_getdate($port);
$port->write('*d');


while (1) {
    do_getdate($port);
    do_getalarm($port);
    sleep 1;
}

$port->write_drain();
$port->close();

exit 0;

sub do_setalarm {
    my ($p, $hour, $minute) = @_;

    die "Failed to send '*A' command"
	unless ($p->write('*A') == 2);

    $p->write(chr(to_bcd($hour))) || die;
    $p->write(chr(to_bcd($minute))) || die;

    die
	unless (read_byte($p) eq '+');
}

sub do_play {
    my ($p, $start, $end) = @_;

    die "Failed to send '*P' command"
	unless ($p->write('*P') == 2);

    # little-endian
    my $buf = pack('V', $start);
    my ($a, $b, $c, $d) = unpack('C4', $buf);
    print "start bytes: $a $b $c $d\n";
    $p->write(chr($a)) || die;
    $p->write(chr($b)) || die;
    $p->write(chr($c)) || die;
    $p->write(chr($d)) || die;

    die "Failed to read marker"
	unless (read_byte($p) eq '+');

    # little-endian
    $buf = pack('V', $end);
    ($a, $b, $c, $d) = unpack('C4', $buf);
    print "end bytes: $a $b $c $d\n";
    $p->write(chr($a)) || die;
    $p->write(chr($b)) || die;
    $p->write(chr($c)) || die;
    $p->write(chr($d)) || die;

    die "Failed to read success"
	unless (read_byte($p) eq '+');
}


sub do_clearhistory {
    my ($p) = @_;

    die "Failed to send '*c' command"
	unless ($p->write('*c') == 2);

    die "Failed to read success"
	unless (read_byte($p) eq '+');
}

sub do_history {
    my ($p) = @_;

    die "Failed to send '*h' command"
	unless ($p->write('*h') == 2);

    foreach my $i (0..255) {
	my $byte = read_byte($p);
	print sprintf("History byte $byte: 0x%.2X\n", ord($byte));
    }

    die "Failed to read success"
	unless (read_byte($p) eq '+');

}

sub do_setlamp {
    my ($p, $mode) = @_;

    print "Setting lamp mode to $mode\n";

    die "Failed to send '*m' command"
	unless ($p->write('*m') == 2);

    $p->write(chr($mode)) || die;
    die "Failed to read success"
	unless (read_byte($p) eq '+');
}

sub do_setdate {
    my ($p, $mon, $day, $year, $dow, $hrs, $mns, $sec) = @_;

    print "Setting date...\n";
    die "Failed to send '*s' command"
	unless ($p->write('*s') == 2);

    my @stuff = ($sec, $mns, $hrs, $dow, $day, $mon, $year);
    foreach my $i (@stuff) {
	$p->write(chr(to_bcd($i))) || die;
    }

    die "Failed to program"
	unless read_byte($p) eq '+';

    foreach my $i (0..6) {
        # Data is BCD.
        my $ret = read_byte($p);
# FIXME: validate that the time that came back matched... if we want.
#        print sprintf("%X\n", unpack('c', $ret));
    }

    print "Done.\n";
}

sub to_bcd {
    my ($val) = @_;

    my $ret = $val % 10;
    $ret |= (int($val / 10 ) << 4);
}

sub do_getalarm {
    my ($p) = @_;

    print "Getting alarm...\n";
    die "Failed to send '*a' command"
	unless ($p->write('*a') == 2);

    my $h = read_byte($p);
    my $m = read_byte($p);
    print sprintf ("Alarm is set for %X:%X\n",
		   unpack('c', $h),
		   unpack('c', $m));

    die
	unless (read_byte($p) eq '+');
}

sub do_getdate {
    my ($p) = @_;
    
    print "Getting date...\n";
    die "Failed to send '*g' command"
	unless ($p->write('*g') == 2);

    my @now;
    foreach my $i (0..6) {
	# Data is BCD.
	my $ret = hex('0x' . read_byte($p) . read_byte($p));
	push (@now, sprintf("%X\n", $ret));
    }

    print sprintf("It is now %2d.%2d.%d %2.2d:%2.2d:%2.2d\n",
		  $now[5], # month
		  $now[4], # day
		  2000 + $now[6], # year
		  $now[2], # hours
		  $now[1], # minutes
		  $now[0], # seconds
	);
}

sub read_byte {
    my ($p) = @_;

    my $counter = 500000;
   
    my ($count, $data);
    do { 
	croak "Failed to read"
	    if ($counter == 0);
	$counter--;
	($count, $data) = $p->read(1);
    } while ($count == 0);

    return $data;
}


