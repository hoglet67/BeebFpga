#!/usr/bin/env perl

#scan the source tree for duplicate files

use strict;

use File::Find;
use Cwd qw(abs_path);
use File::Basename qw( dirname basename );
use Digest::CRC qw( crc16 );
use File::Slurp;
use Data::Dumper;

my @sources = ();
my @prjs = ();

$|++;
find({ wanted => \&file_wanted, no_chdir => 1}, '.');


sub add_source($$$) {
	my ($pathname, $directory, $filename) = @_;

	my $contents = read_file($_);
	$contents =~ s/[\s\r\n]+//;
	my $crc = crc16($contents);
	print ".";
	push(@sources, { path => $pathname, file => $filename, crc => $crc});
}

sub add_prj($$$) {
	my ($pathname, $directory, $filename) = @_;
	
	print "#";
	my $contents = read_file($_);
	push(@prjs, { prj => $pathname, contents => $contents });	
}

sub file_wanted() {
#	print "$_\n";
	if (/\.(v|vhd|vhdl|sv)$/ && -f "$_") {
		add_source($File::Find::name, $File::Find::dir, basename($File::Find::name));
	} elsif (/\.(gprj|qsf|xise)/ && -f "$_" ) {
		add_prj($File::Find::name, $File::Find::dir, basename($File::Find::name));
	}
}


my %filenames = ();

foreach my $s (@sources) {
	my $f = $s->{file};
	my $crc = $s->{crc};
	my $path = $s->{path};

	if (!exists $filenames{$f}) {
		$filenames{$f} = {$crc => [ $path ]};
	} else {
		my $x = $filenames{$f};
		if (exists $x->{$crc}) {
			push @{$x->{$crc}}, $path;
		} else {
			$x->{$crc} = [ $path ];
		}
	}
}

print "\n\nDuplicate filenames\n====================\n";

foreach my $f (sort keys %filenames) {
	my %crcs = %{$filenames{$f}};

	if (scalar %crcs > 1) {
		print "$f\n";
		foreach my $c (sort keys %crcs) {
			print "    $c\n";
			foreach my $r (sort @{%crcs{$c}}) {
				print "        $r\n";
			}
		}
		foreach my $p (@prjs) {
			if ($p->{contents} =~ /$f/i) {
				print "     ->  $p->{prj}\n";
			}
		}		
	}
}