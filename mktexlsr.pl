#!/usr/bin/perl

use strict;
$^W = 1;

use File::Find;

my %lsdirs;

print '% ls-R -- filename database for kpathsea; do not change this line.';

find({ wanted => \&donothing , preprocess => \&dir_preprocess }, qw!/home/norbert/tl/2014/texmf-dist!);

sub donothing {
}

sub doit {
  if (-d $_) { 
    print "\n$_:\n"; 
  } else {
    print "$_\n";
  }
}

sub dir_preprocess {
  my $rel = $File::Find::dir;
  $rel =~ s!^$File::Find::topdir!.!;
  print "\n$rel:\n";
  my @ds;
  for my $f (sort @_) {
    next if ($f eq ".");
    next if ($f eq "..");
    print "$f\n";
    if (-d $f) {
      push @ds, $f;
    }
  }
  return @ds;
}
