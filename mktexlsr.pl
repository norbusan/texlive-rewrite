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

my $ismain;

BEGIN {
  $^W = 1;
  $ismain = (__FILE__ eq $0);
}

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
use File::Spec;
use File::Find;
use File::Basename;
#use Data::Dumper;
#$Data::Dumper::Indent = 1;

my $opt_dryrun = 0;
my $opt_help   = 0;
my $opt_verbose = 1; # TODO should be 0 when not connected to a terminal!
                     # in shell by checking tty -s
my $opt_version = 0;
my $opt_output;

(my $prg = basename($0)) =~ s/\.pl$//;

my $lsrmagic = 
  '% ls-R -- filename database for kpathsea; do not change this line.';
my $oldlsrmagic = 
  '% ls-R -- maintained by MakeTeXls-R; do not change this line.';


&main() if $ismain;


#
# usage as module
#

package TeX::LSR;

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    root => $params{'root'},
    filename => '',           # to accomodated both ls-r and ls-R
    is_loaded => 0,
    tree => { }
  };
  bless $self, $class;
  return $self;
}

# returns 1 on success, 0 on failure
sub loadtree {
  my $self = shift;
  return 0 if (!defined($self->{'root'}));
  return 0 if (! -d $self->{'root'});
  my $tree;
  build_tree($tree, $self->{'root'});
  $self->{'tree'} = $tree->{$self->{'root'}};
  #
  # crazy code from 
  # http://www.perlmonks.org/?node=How%20to%20map%20a%20directory%20tree%20to%20a%20perl%20hash%20tree
  {
    sub build_tree {
      my $node = $_[0] = {};
      my @s;
      File::Find::find( sub {
        $node = (pop @s)->[1] while @s and $File::Find::dir ne $s[-1][0];
        # ignore VCS
        return if ($_ eq ".git");
        return if ($_ eq ".svn");
        return if ($_ eq ".hg");
        return if ($_ eq ".bzr");
        # do NOT follow symlinks and check them
        # this is a difference to the original mktexlsr implementation
        return $node->{$_} = 1 if (! -d);
        push @s, [ $File::Find::name, $node ];
        $node = $node->{$_} = {};
      }, $_[1]);
      $_[0]{$_[1]} = delete $_[0]{'.'};
    }
  }
  $self->{'is_loaded'} = 1;
  return 1;
}

sub setup_filename {
  my $self = shift;
  if (!$self->{'filename'}) {
    if (-r $self->{'root'} . "/ls-R") {
      $self->{'filename'} = 'ls-R';
    } elsif (-r $self->{'root'} . "/ls-r") {
      $self->{'filename'} = 'ls-r';
    } else {
      $self->{'filename'} = 'ls-R';
    }
  }
  return 1;
}

sub loadfile {
  my $self = shift;
  return 0 if (!defined($self->{'root'}));
  return 0 if (! -d $self->{'root'});
  $self->setup_filename();
  my $lsrfile = File::Spec->catfile($self->{'root'},$self->{'filename'});
  return 0 if (! -r $lsrfile);
  open FOO, "<", $lsrfile || die ("$prg: really readable $lsrfile: $?");
  # check first line for the magic header
  chomp (my $fl = <FOO>);
  if (($fl eq $lsrmagic) or ($fl eq $oldlsrmagic)) {
    my %tree;
    my $t;
    for my $l (<FOO>) {
      chomp($l);
      next if ($l =~ m!^\s*$!);
      next if ($l =~ m!^\./:!);
      if ($l =~ m!^(.*):!) {
        $t = \%tree;
        my @a = split(/\//,$1);
        for (@a) {
          $t->{$_} = {} if (!defined($t->{$_}) or ($t->{$_} == 1));
          $t = $t->{$_};
        }
      } else {
        $t->{$l} = 1;
      }
    }
    $self->{'tree'} = $tree{'.'};
  }
  close(FOO);
  $self->{'is_loaded'} = 1;
  return 1;
}

sub write {
  my ($self, $fn) = @_;
  if (!defined($self->{'root'})) {
    print STDERR "TeX::LSR: root undefined, cannot write out.\n";
    return 0;
  }
  if ($self->{'is_loaded'} == 0) {
    print STDERR "TeX::LSR: tree for ", $self->{'root'}, " not loaded, cannot write out!\n";
    return 0;
  }
  if (!defined($fn)) {
    $self->setup_filename();
    $fn = $self->{'filename'};
  }
  if (-e $fn && ! -w $fn) {
    print STDERR "TeX::LSR: ls-R file at $fn is not writable, skipping.\n";
    return 0;
  }
  open FOO, ">$fn" ||
    die "TeX::LSR writable but cannot open?? $?";
  print FOO "$lsrmagic\n\n";
  print FOO "./:\n";  # hardwired ./ for top-level files -- really necessary?
  do_entry($self->{'tree'}, ".");
  {
    sub do_entry {
      my $t = shift;
      my $n = shift;
      print FOO "$n:\n";
      my @sd;
      for my $st (keys %$t) {
        push @sd, $st if (ref($t->{$st}) eq 'HASH');
        print FOO "$st\n";
      }
      print FOO "\n";
      for my $st (@sd) {
        do_entry($t->{$st}, "$n/$st");
      }
    }
  }
  return 1;
}


package main;


################

sub main {
  GetOptions("dry-run|n"      => \$opt_dryrun,
             "help|h"         => \$opt_help,
             "verbose"        => \$opt_verbose,
             "quiet|q|silent" => sub { $opt_verbose = 0 },
             "output|o=s"     => \$opt_output,
             "version|v"      => \$opt_version) or
    die "Try \"$prg --help\" for more information.\n";

  help() if $opt_help;

  if ($opt_version) {
    print version();
    exit (0);
  }

  if ($opt_output && $#ARGV != 0) {
    # we only support --output with only one tree as argument
    print STDERR "$prg: using of --output <file> also requires exactely one tree as argument.";
    exit (1);
  }

  for my $t (find_lsr_trees()) {
    my $lsr = new TeX::LSR(root => $t);
    if ($lsr->loadtree()) {
      if ($opt_output) {
        $lsr->write($opt_output);
      } else {
        $lsr->write();
      }
    } else {
      print STDERR "$prg: cannot read $t files, skipping!\n";
    }
    # only as example how to load a ls-R file
    # my $lsrfile = new TeX::LSR(root => $t);
    # if ($lsrfile->loadfile()) {
    #   print "success loading tree from $t\n";
    #   print "\n\n========= $t =============\n\n";
    #   print Dumper $lsrfile->{'tree'};
    # } else {
    #   print "bad luck with $t\n";
    # }
  }
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
  --output NAME
             if exactly one DIR is given, the ls-R file will be written to NAME
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

__END__

HISTORIC STUFF!!!

sub create_lsr_file {
  my $t = shift;
  # TODO find ls-R versus ls-r, use as is, but create ls-R
  # TODO follow ls-R link
  print $lsrmagic;
  print "\n./:";  # hardwired ./ for top-level files -- really necessary?
  find({ wanted => sub { } , preprocess => \&dir_preprocess }, $t);
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

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
