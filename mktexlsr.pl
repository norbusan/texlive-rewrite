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
use Cwd;
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

  help() if $opt_help;

  if ($opt_version) {
    print version();
    exit (0);
  }

  for my $t (find_lsr_trees()) {
    print "\n\n========= $t =============\n\n";
    create_lsr_file($t);
  }
}

sub create_lsr_file {
  my $t = shift;
  # TODO find ls-R versus ls-r, use as is, but create ls-R
  # TODO follow ls-R link
  print $lsrmagic;
  print "\n./:";  # hardwired ./ for top-level files -- really necessary?
  find({ wanted => sub { } , preprocess => \&dir_preprocess }, $t);
}

sub find_lsr_trees {
  my %lsrs;
  my @candidates = @ARGV;
  if (!@candidates) {
    # the shellfile used kpsewhich --show-path=ls-R | tr : '\n' 
    # seems to be simpler than using -var-value TEXMFDBS and
    # fixing the return value
    chomp( my $t = `kpsewhich -show-path=ls-R` );
    @candidates = split(':', $t);
  }
  for my $t (@candidates) {
    my $ret;
    eval {$ret = Cwd::abs_path($t);}; # eval needed for w32
    if ($ret) {
      $lsrs{$ret} = 1;
    } else {
      # ignored, we simply skip direcoroies that don't exist
    }
  }
  return sort(keys %lsrs);
}


sub dir_preprocess {
  my $rel = $File::Find::dir;
  $rel =~ s!^$File::Find::topdir!.!;
  print "\n$rel:\n";
  my @ds;
  # the shell script sorted here, but this seems not to be necessary
  for my $f (@_) {
    next if ($f eq ".");
    next if ($f eq "..");
    next if ($f eq ".git");
    next if ($f eq ".svn");
    next if ($f eq ".hg");
    next if ($f eq ".bzr");
    print "$f\n";
    if (-d $f) {
      push @ds, $f;
    }
  }
  return @ds;
}

sub version {
  my $ret = sprintf "%s version %s\n", $prg, $version;
  return $ret;
}

sub help {
  my $usage = <<"EOF"
Usage: $prg [OPTION]... [DIR]...

Rebuild ls-R filename databases used by TeX.  If one or more arguments
DIRS are given, these are used as the directories in which to build
ls-R. Else all directories in the search path for ls-R files
(\$TEXMFDBS) are used.

Options:
  --dry-run  do not actually update anything
  --help     display this help and exit 
  --quiet    cancel --verbose
  --silent   same as --quiet
  --verbose  explain what is being done
  --version  output version information and exit
  
If standard input is a terminal, --verbose is on by default.

For more information, see the \`Filename database' section of
Kpathsea manual available at http://tug.org/kpathsea.

Report bugs to: tex-k\@tug.org
TeX Live home page: <http://tug.org/texlive/>

EOF
;
  print &version();
  print $usage;
  exit 0;
}


### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
