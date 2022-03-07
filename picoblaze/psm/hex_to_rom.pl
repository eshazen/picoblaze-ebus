#!/usr/bin/perl
#
# read hex file from picoblaze assembler and output inferred ROM initializer
# read a template VHDL file looking for <SIZE> and <DATA>
#
use strict;

my $na = $#ARGV+1;

if( $na < 2) {
    print "Usage:  $0 input.hex my_ROM_template.vhd [minimum_size]> my_ROM.vhd\n";
    exit;
}

my $romsize = 256;		# default size
if( $na == 3) {
    $romsize = $ARGV[2];
}

open HEX, "< $ARGV[0]" or die "Opening $ARGV[0]";
open TPL, "< $ARGV[1]" or die "Opening $ARGV[1]";

my @words;

while( my $line = <HEX>) {		# read the hex file
    $line =~ s/[[:cntrl:]]//g;	# clean crud from line
    push @words, $line;
}
my $nwords = $#words;
$nwords-- while( $words[$nwords] == "00000"); # find last non-zero word
$nwords += 2;			# add a couple for safety

print "---- non-zero words: ", $nwords, "\n";

if( $nwords < $romsize) {
    my $fill = $romsize - $nwords;
    print "---- FILLING with $fill ----\n";
    $nwords += $fill;
}

my $nw = $nwords-1;

while( my $line = <TPL>) {
    $line =~ s/[[:cntrl:]]//g;	# clean crud from line
#    print "TPL: $line";
    if( $line =~ /<SIZE>/) {
	$line =~ s/<SIZE>/$nw/;
	print "$line\n";
    } elsif( $line =~ /<DATA>/) {
	for( my $i=0; $i<$nwords; $i++) {
	    print qq{    X"$words[$i]",\n} if( $i < $nwords-1);
	    print qq{    X"$words[$i]"\n} if( $i == $nwords-1);
	}
    } else {
	print "$line\n";
    }
}

