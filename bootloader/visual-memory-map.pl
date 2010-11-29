#!/usr/bin/perl

use strict;
use warnings;
use Curses;

# Display memory usage on a terminal. This compresses horizontally by
# $hcompress, and vertically by $vcompress.

our $maxmem = 0x2000;
our $hcompress = 4;
our $vcompress = 64;

my %bits;
if (0) {
    # Could conceivably read main.map and turn it into something like this:
    %bits = ( '.' => [ 0, 0x02] ,
	      'o' => [ 4, 0x02] ,
	      'r' => [ 5, 0x41e] ,
	      'p' => [ 0x214, 0x18],
	      'g' => [ 0x220, 0x56],
	      'd' => [ 0x24b, 0x210],
	      'm' => [ 0x353, 0x78],
	      's' => [ 0x38f, 0x60],
	      'e' => [ 0x3bf, 0x26],
	      '4' => [ 0x400, 0x604],
	      'c' => [ 0x2007, 0x2],
	);
}

initscr;

print_table();

while (<STDIN>) {
    chomp;
    my ($num, $address, $type) = (/^:(..)(....)(..)/);
    if ($type eq '00') {
	$address = hex($address);
	$num = hex($num);
	foreach my $i (int($address/2) .. int(($address+$num)/2)) {
	    used('+', $i);
	}
    }
}

if (0) {
    foreach my $key (keys %bits) {
	my ($start, $len) = @{$bits{$key}};
	$len /= 2; # lengths were in bytes, not words of program memory
	
	foreach my $i ($start..$start+$len) {
	    used($key, $i);
	}
    }
}

endwin;

exit 0;

sub print_table {
    foreach my $i (0..($maxmem/($vcompress*$hcompress))-1) {
	addstr($i, 0, sprintf("0x%.4X", $i * ($vcompress*$hcompress)));
    }
    foreach my $i (0..$maxmem) {
	used('_', $i);
    }
}

sub used {
    my ($key, $mem) = @_;

    return
	unless $mem < $maxmem;

    my $y = int($mem / ($vcompress*$hcompress));
    my $x = int( ($mem % ($vcompress*$hcompress)) / $hcompress) + 15;
    addch($y, $x, $key);
    refresh();
}
