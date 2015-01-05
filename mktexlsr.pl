#!/usr/bin/env perl
#
# Copyright 2015 Norbert Preining
#
# This file is licensed under the GNU General Public License version 2
# or any later version.
#
# History:
# Original shell script (C) 1994 Thomas Esser (as texhash), Public domain.
#

use strict;
$^W = 1;

# for future inclusion in TeX Live svn:
my $svnid = '$Id:$';
my $lastchdate = '$Date:$';
$lastchdate =~ s/^\$Date:\s*//;
$lastchdate =~ s/ \(.*$//;
my $svnrev = '$Revision:$';
$svnrev =~ s/^\$Revision:\s*//;
$svnrev =~ s/\s*\$$//;
my $version = "svn$svnrev ($lastchdate)";

use Getopt::Long qw(:config no_autoabbrev ignore_case_always);
use File::Find;
use File::Basename;

my $opt_dryrun = 0;
my $opt_help   = 0;
my $opt_verbose = 1; # TODO should be 0 when not connected to a terminal!
                     # in shell by checking tty -s
my $opt_version = 0;

(my $prg = basename($0)) =~ s/\.pl$//;

my $lsrmagic = 
  '% ls-R -- filename database for kpathsea; do not change this line.';
my $oldlsrmagic = 
  '% ls-R -- maintained by MakeTeXls-R; do not change this line.';


&main();

################

sub main {
  GetOptions("dry-run|n"      => \$opt_dryrun,
             "help|h"         => \$opt_help,
             "verbose"        => \$opt_verbose,
             "quiet|q|silent" => sub { $opt_verbose = 0 },
             "version|v"      => \$opt_version) or
    die "Try \"$prg --help\" for more information.\n";
  print $lsrmagic;
  print "\n./:";  # hardwired ./ for top-level files -- really necessary?

  find({ wanted => sub { } , preprocess => \&dir_preprocess }, qw!/home/norbert/tl/2014/texmf-dist!);
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

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
