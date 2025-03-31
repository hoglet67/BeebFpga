#!/usr/bin/perl

# read a QSF file and output a list of dependencies of the type specified as arguments

# getdeps.pl <dependency> [<QSF names>...]

use strict;
use experimental;

my $dep = shift or die "no dependency filename given";

scalar @ARGV > 0 or die "no names";

my @files = ();

my $any = join '|', @ARGV;

my $rex = qr/^\s*set_global_assignment\s+\-name\s+($any)\s+([^\s]+)/;

while (<stdin>) {

	my $l = $_;
	$l =~ s/\r$//;


	if ($l =~ /$rex/)
	{

		my $val = $2;
		push @files, $2;
	}

}

print "$dep: ${\join(' ', @files) }\n";