#!/usr/bin/perl

open(F, "version-count") || die "ERROR: failed to open version count: $!";

my $next = <F>;
chomp $next;

my $uebernext=($next+1)%256;
$uebernext++
    if ($uebernext == 0);

print sprintf "next version id: 0x%.2X\n", $next;

close F;
open(F, ">version-count") || die "ERROR: unable to write version count: $!";
print F $uebernext, "\n";
close F;

exit($next);
