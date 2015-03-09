#!/usr/bin/env perl
# $Id: fmtutil.pl 33988 2014-05-12 06:39:32Z preining $
# fmtutil - utility to maintain format files.
# (Maintained in TeX Live:Master/texmf-dist/scripts/texlive.)
# 
# Copyright 2014 Norbert Preining
# This file is licensed under the GNU General Public License version 2
# or any later version.
#
# History:
# Original shell script (C) 2001 Thomas Esser, public domain

my $TEXMFROOT;

BEGIN {
  $^W=1;
  $TEXMFROOT = `kpsewhich -var-value=TEXMFROOT`;
  if ($?) {
    print STDERR "fmtutil: Cannot find TEXMFROOT, aborting!\n";
    exit 1;
  }
  chomp($TEXMFROOT);
  unshift (@INC, "$TEXMFROOT/tlpkg");
}


my $svnid = '$Id: fmtutil.pl 33988 2014-05-12 06:39:32Z preining $';
my $lastchdate = '$Date: 2014-05-12 15:39:32 +0900 (Mon, 12 May 2014) $';
$lastchdate =~ s/^\$Date:\s*//;
$lastchdate =~ s/ \(.*$//;
my $svnrev = '$Revision: 33988 $';
$svnrev =~ s/^\$Revision:\s*//;
$svnrev =~ s/\s*\$$//;
my $version = "svn$svnrev ($lastchdate)";

use Getopt::Long qw(:config no_autoabbrev ignore_case_always);
use strict;
use TeXLive::TLUtils qw(mkdirhier mktexupd win32 basename dirname 
  sort_uniq member touch);

#use Data::Dumper;
#$Data::Dumper::Indent = 1;

(our $prg = basename($0)) =~ s/\.pl$//;

# sudo sometimes does not reset the home dir of root, check on that
# see more comments at the definition of the function itself
# this function checks by itself whether it is running on windows or not
reset_root_home();

chomp(our $TEXMFDIST = `kpsewhich --var-value=TEXMFDIST`);
chomp(our $TEXMFVAR = `kpsewhich -var-value=TEXMFVAR`);
chomp(our $TEXMFSYSVAR = `kpsewhich -var-value=TEXMFSYSVAR`);
chomp(our $TEXMFCONFIG = `kpsewhich -var-value=TEXMFCONFIG`);
chomp(our $TEXMFSYSCONFIG = `kpsewhich -var-value=TEXMFSYSCONFIG`);
chomp(our $TEXMFHOME = `kpsewhich -var-value=TEXMFHOME`);

# make sure that on windows *everything* is in lower case for comparison
if (win32()) {
  $TEXMFDIST = lc($TEXMFDIST);
  $TEXMFVAR = lc($TEXMFVAR);
  $TEXMFSYSVAR = lc($TEXMFSYSVAR);
  $TEXMFCONFIG = lc($TEXMFCONFIG);
  $TEXMFSYSCONFIG = lc($TEXMFSYSCONFIG);
  $TEXMFROOT = lc($TEXMFROOT);
  $TEXMFHOME = lc($TEXMFHOME);
}

#
# these need to be our since they are used from the 
# functions in TLUtils.pm
our $texmfconfig = $TEXMFCONFIG;
our $texmfvar    = $TEXMFVAR;
our $alldata;
our %opts = ( quiet => 0 );
our @cmdline_options = (
  "sys",
  "cnffile=s@", 
  "fmtdir=s",
  "no-engine-subdir",
  "no-error-if-no-engine=s",
  "quiet|silent|q",
  "test",
  "dolinks",
  "force",
  "all",
  "missing",
  "nohash",
  "refresh",
  "byengine=s",
  "byfmt=s",
  "byhyphen=s",
  "enablefmt=s",
  "disablefmt=s",
  "listcfg",
  "catcfg",
  "showhyphen=s",
  "edit",
  "version",
  "help|h",
  "_dumpdata",
  );

my $updLSR;

&main();

###############

sub main {
  GetOptions(\%opts, @cmdline_options) or 
      die "Try \"$prg --help\" for more information.\n";

  help() if $opts{'help'};

  if ($opts{'version'}) {
    print version();
    exit (0);
  }

  # these two functions should go to TLUtils!
  check_hidden_sysmode();
  determine_config_files("fmtutil.cnf");
  my $changes_config_file = $alldata->{'changes_config'};

  read_fmtutil_files(@{$opts{'cnffile'}});

  # we do changes always in the used config file with the highest
  # priority
  my $bakFile = $changes_config_file;
  $bakFile =~ s/\.cfg$/.bak/;
  my $changed = 0;

  $updLSR = &mktexupd();
  $updLSR->{mustexist}(0);

  my $cmd;
  if ($opts{'edit'}) {
    if ($opts{"dry-run"}) {
      printf STDERR "No, are you joking, you want to edit with --dry-run?\n";
      exit 1;
    }
    # it's not a good idea to edit fmtutil.cnf manually these days,
    # but for compatibility we'll silently keep the option.
    $cmd = 'edit';
    my $editor = $ENV{'VISUAL'} || $ENV{'EDITOR'};
    $editor ||= (&win32 ? "notepad" : "vi");
    if (-r $changes_config_file) {
      &copyFile($changes_config_file, $bakFile);
    } else {
      touch($bakFile);
      touch($changes_config_file);
    }
    system($editor, $changes_config_file);
    $changed = files_are_different($bakFile, $changes_config_file);
  } elsif ($opts{'showhyphen'}) {
    my $f = $opts{'showhyphen'};
    if ($alldata->{'merged'}{$f}) {
      my @all_engines = keys %{$alldata->{'merged'}{$f}};
      for my $e (sort @all_engines) {
        my $hf = $alldata->{'merged'}{$f}{$e}{'hyphen'};
        next if ($hf eq '-');
        my $ff = `kpsewhich -progname=$f -format=tex $hf`;
        chomp($ff);
        if ($ff ne "") {
          if ($#all_engines > 0) {
            printf "$f/$e: ";
          }
          printf "$ff\n";
        } else {
          warning("hyphenfile $hf (for $f/$e) not found!\n");
          abort();
        }
      }
    }
  } elsif ($opts{'catcfg'}) {
    warning("$prg: --catcfg command not supported anymore!\n");
    exit(1);
  } elsif ($opts{'listcfg'}) {
    warning("$prg: --listcfg currently not implemented, be patient!\n");
    exit(1);
  } elsif ($opts{'disablefmt'}) {
    return callback_enable_disable_format($changes_config_file, 
                                          $opts{'enablefmt'}, 'disabled');
  } elsif ($opts{'enablefmt'}) {
    return callback_enable_disable_format($changes_config_file, 
                                          $opts{'enablefmt'}, 'enabled');
  } elsif ($opts{'byfmt'}) {
    return callback_build_formats('byfmt', $opts{'byfmt'});
  } elsif ($opts{'byengine'}) {
    return callback_build_formats('byengine', $opts{'byengine'});
  } elsif ($opts{'byhyphen'}) {
    return callback_build_formats('byhyphen', $opts{'byhyphen'});
  } elsif ($opts{'refresh'}) {
    return callback_build_formats('refresh');
  } elsif ($opts{'missing'}) {
    return callback_build_formats('missing');
  } elsif ($opts{'all'}) {
    return callback_build_formats('all');
  } elsif ($opts{'_dumpdata'}) {
    dump_data();
    exit(0);
  } else {
    warning("$prg: missing command; try fmtutil --help if you need it.\n");
    exit(1);
  }

  if (!$opts{'nohash'}) {
    print "$prg: Updating ls-R files.\n" if !$opts{'quiet'};
    $updLSR->{exec}() unless $opts{"dry-run"};
  }

  return 0;
}

sub dump_data {
  require Data::Dumper;
  $Data::Dumper::Indent = 1;
  $Data::Dumper::Indent = 1;
  print Data::Dumper::Dumper($alldata);
}


# build_formats
# (re)builds the formats as selected

sub callback_build_formats {
  my ($what, $whatarg) = @_;
  my $suc = 0;
  my $err = 0;
  my $nobuild = 0;
  # we rebuild formats in two rounds:
  # round 1: only formats with the same name as engine (pdftex/pdftex)
  # round 2: all other formats
  # reason: later formats might need earlier formats to be already
  # initialized (xmltex is one of these examples AFAIR)
  my $val;
  for my $fmt (keys %{$alldata->{'merged'}}) {
    for my $eng (keys %{$alldata->{'merged'}{$fmt}}) {
      next if ($fmt ne $eng);
      $val = select_and_rebuild_format($fmt, $eng, $what, $whatarg);
      if ($val == 0) { $nobuild++; }
      elsif ($val == -1) { $err++; }
      elsif ($val == 1)  { $suc++; }
      else { print_error("callback_build_format: unknown return from select_and_rebuild.\n"); }
    }
  }
  for my $fmt (keys %{$alldata->{'merged'}}) {
    for my $eng (keys %{$alldata->{'merged'}{$fmt}}) {
      next if ($fmt eq $eng);
      $val = select_and_rebuild_format($fmt, $eng, $what, $whatarg);
      if ($val == 0) { $nobuild++; }
      elsif ($val == -1) { $err++; }
      elsif ($val == 1)  { $suc++; }
      else { print_error("callback_build_format: unknown return from select_and_rebuild.\n"); }
    }
  }
  print_info("Successfully rebuild formats: $suc\n") if ($suc);
  print_warning("Not rebuild formats: $nobuild\n") if ($nobuild);
  print_warning("Failure during builds: $err\n") if ($err);
  return 0;
}

# select_and_rebuild_format
# check condition and rebuild the format if selected
# return values:
# 1 success
# 0 not selected
# -1 failure
sub select_and_rebuild_format {
  my ($fmt, $eng, $what, $whatarg) = @_;
  return(0) if ($alldata->{'merged'}{$fmt}{$eng}{'status'} eq 'disabled');
  my $doit = 0;
  # we just identify 'all', 'refresh', 'missing'
  # I don't see much point in keeping all of them
  $doit = 1 if ($what eq 'all');
  $doit = 1 if ($what eq 'refresh');
  $doit = 1 if ($what eq 'missing');
  $doit = 1 if ($what eq 'byengine' && $eng eq $whatarg);
  $doit = 1 if ($what eq 'byfmt' && $fmt eq $whatarg);
  $doit = 1 if ($what eq 'byhyphen' &&
                $whatarg eq 
                (split(/,/ , $alldata->{'merged'}{$fmt}{$eng}{'hyphen'}))[0]);
  if ($doit) {
    return rebuild_one_format($fmt,$eng);
  } else {
    return 0;
  }
}

# rebuild_one_format
# takes fmt/eng and rebuilds it, irrelevant of any setting
# return value
# 1 success
# -1 error
sub rebuild_one_format {
  my ($fmt, $eng) = @_;
  print_warning("rebuild_one_format: not implemented: $fmt/$eng\n");
  return -1;
}


#
# enable_disable_format_engine
# assumes that format/engine is already defined somewhere,
# i.e., it $alldata->{'merged'}{$fmt}{$eng} is defined
#
# Return values:
# 1 - success with changes
# 0 - no changes done
# -1 - error appeared
sub enable_disable_format_engine {
  my ($tc, $fmt, $eng, $mode) = @_;
  if ($mode eq 'enabled' || $mode eq 'disabled') {
    if ($alldata->{'merged'}{$fmt}{$eng}{'status'} eq $mode) {
      print_info("Format/engine combination $fmt/$eng already $mode.\n");
      print_info("No changes done.\n");
      return 0;
    } else {
      my $origin = $alldata->{'merged'}{$fmt}{$eng}{'origin'};
      if ($origin ne $tc) {
        $alldata->{'fmtutil'}{$tc}{'formats'}{$fmt}{$eng} =
          {%{$alldata->{'fmtutil'}{$origin}{'formats'}{$fmt}{$eng}}}
      }
      $alldata->{'fmtutil'}{$tc}{'formats'}{$fmt}{$eng}{'status'} = $mode;
      $alldata->{'fmtutil'}{$tc}{'formats'}{$fmt}{$eng}{'line'} = -1;
      $alldata->{'fmtutil'}{$tc}{'formats'}{$fmt}{$eng}{'changed'} = 1;
      $alldata->{'merged'}{$fmt}{$eng}{'status'} = $mode;
      $alldata->{'merged'}{$fmt}{$eng}{'origin'} = $tc;
      dump_data();
      return save_fmtutil($tc);
    }
  } else {
    print_error("enable_disable_format_engine: unknown mode $mode\n");
    exit(1);
  }
}  

#
# enable a format named
#   format[/engine]
# where the engine part is optional
# Case 1: no "engine" given:
# - if format is defined and has only one engine instance -> activate
# - if format is defined and has more than one engine -> error
# Case 2: engine given:
# - if format/engine is defined -> activate
# - if format/engine is not defined -> error
#
# Return values:
# 1 - success with changes
# 0 - no changes done
# -1 - error appeared
sub callback_enable_disable_format {
  my ($tc, $fmtname, $mode) = @_;
  my ($fmt, $eng) = split('/', $fmtname, 2);
  if ($mode ne 'enabled' && $mode ne 'disabled') {
    print_error("callback_enable_disable_format: unknown mode $mode.\n");
    exit 1;
  }
  if ($eng) {
    if ($alldata->{'merged'}{$fmt}{$eng}) {
      return enable_disable_format_engine($tc, $fmt, $eng, $mode);
    } else {
      print_warning("Format/engine combination: $fmt/$eng is not defined.\n");
      print_warning("Cannot (de)activate it.\n");
      return -1;
    }
  } else {
    # no engine given, check the number of entries
    if ($alldata->{'merged'}{$fmt}) {
      my @engs = keys %{$alldata->{'merged'}{$fmt}};
      if (($#engs > 0) || ($#engs == -1)) {
        print_warning("More engines given for format $fmt.\n");
        print_warning("Please specify one of the engines: @engs\n");
        print_warning("No changes done.\n");
        return 0;
      } else {
        # only one engine, enable it if necessary!
        return enable_disable_format_engine($tc, $fmt, $engs[0], $mode);
      }
    } else {
      print_warning("Format $fmt is not defined.\n");
      print_warning("Cannot (de)activate it.\n");
      return -1;
    }
  }
}

sub read_fmtutil_files {
  my (@l) = @_;
  for my $l (@l) { read_fmtutil_file($l); }
  # in case the changes_config is a new one read it in and initialize it here
  my $cc = $alldata->{'changes_config'};
  if (! -r $cc) {
    $alldata->{'fmtutil'}{$cc}{'lines'} = [ ];
  }
  #
  $alldata->{'order'} = \@l;
  #
  # determine the origin of all formats
  for my $fn (reverse @l) {
    my @format_names = keys %{$alldata->{'fmtutil'}{$fn}{'formats'}};
    for my $f (@format_names) {
      for my $e (keys %{$alldata->{'fmtutil'}{$fn}{'formats'}{$f}}) {
        $alldata->{'merged'}{$f}{$e}{'origin'} = $fn;
        $alldata->{'merged'}{$f}{$e}{'hyphen'} = 
            $alldata->{'fmtutil'}{$fn}{'formats'}{$f}{$e}{'hyphen'} ;
        $alldata->{'merged'}{$f}{$e}{'status'} = 
            $alldata->{'fmtutil'}{$fn}{'formats'}{$f}{$e}{'status'} ;
        $alldata->{'merged'}{$f}{$e}{'args'} = 
            $alldata->{'fmtutil'}{$fn}{'formats'}{$f}{$e}{'args'} ;
      }
    }
  }
}

sub read_fmtutil_file {
  my $fn = shift;
  if (!open(FN,"<$fn")) {
    die ("Cannot read $fn: $!");
  }
  # we count lines from 0 ..!!!!
  my $i = -1;
  my @lines = <FN>;
  chomp(@lines);
  $alldata->{'fmtutil'}{$fn}{'lines'} = [ @lines ];
  close(FN) || warn("$prg: Cannot close $fn: $!");
  for (@lines) {
    $i++;
    chomp;
    next if /^\s*$/;
    next if /^\s*#$/;
    next if /^\s*#[^!]/;
    next if /^\s*##/;
    next if /^#![^ ]/;
    # allow for comments on the line itself
    s/([^#].*)#.*$/$1/;
    my ($a, $b, $c, @rest) = split ' ';
    my $disabled = 0;
    if ($a eq "#!") {
      # we cannot determine whether a line is a proper fmtline or
      # not, so we have to assume that it is
      my $d = shift @rest;
      if (!defined($d)) {
        warning("$prg: apparently not a real disable line, ignored: $_\n");
        next;
      } else {
        $disabled = 1;
        $a = $b; $b = $c; $c = $d;
      }
    }
    if (defined($alldata->{'fmtutil'}{$fn}{'formats'}{$a}{$b})) {
      warning("$prg: double mention of $a/$b in $fn\n");
    } else {
      $alldata->{'fmtutil'}{$fn}{'formats'}{$a}{$b}{'hyphen'} = $c;
      $alldata->{'fmtutil'}{$fn}{'formats'}{$a}{$b}{'args'} = "@rest";
      $alldata->{'fmtutil'}{$fn}{'formats'}{$a}{$b}{'status'} = ($disabled ? 'disabled' : 'enabled');
      $alldata->{'fmtutil'}{$fn}{'formats'}{$a}{$b}{'line'} = $i;
    }
  }
}



#
# FUNCTIONS THAT SHOULD GO INTO TLUTILS.PM
# and also be reused in updmap.pl!!!
#


sub check_hidden_sysmode {
  #
  # check if we are in *hidden* sys mode, in which case we switch
  # to sys mode
  # Nowdays we use -sys switch instead of simply overriding TEXMFVAR
  # and TEXMFCONFIG
  # This is used to warn users when they run updmap in usermode the first time.
  # But it might happen that this script is called via another wrapper that
  # sets TEXMFCONFIG and TEXMFVAR, and does not pass on the -sys option.
  # for this case we check whether the SYS and non-SYS variants agree,
  # and if, then switch to sys mode (with a warning)
  if (($TEXMFSYSCONFIG eq $TEXMFCONFIG) && ($TEXMFSYSVAR eq $TEXMFVAR)) {
    if (!$opts{'sys'}) {
      warning("$prg: hidden sys mode found, switching to sys mode.\n");
      $opts{'sys'} = 1;
    }
  }



  if ($opts{'sys'}) {
    # we are running as updmap-sys, make sure that the right tree is used
    $texmfconfig = $TEXMFSYSCONFIG;
    $texmfvar    = $TEXMFSYSVAR;
  }
}


sub determine_config_files {
  my $fn = shift;

  # config file for changes
  my $changes_config_file;

  # determine which config files should be used
  # we also determine here where changes will be saved to
  if ($opts{'cnffile'}) {
    my @tmp;
    for my $f (@{$opts{'cnffile'}}) {
      if (! -f $f) {
        die "$prg: Config file \"$f\" not found.";
      }
      push @tmp, (win32() ? lc($f) : $f);
    }
    @{$opts{'cnffile'}} = @tmp;
    # in case that config files are given on the command line, the first
    # in the list is the one where changes will be written to.
    ($changes_config_file) = @{$opts{'cnffile'}};
  } else {
    my @all_files = `kpsewhich -all $fn`;
    chomp(@all_files);
    my @used_files;
    for my $f (@all_files) {
      push @used_files, (win32() ? lc($f) : $f);
    }
    #
    my $TEXMFLOCALVAR;
    my @TEXMFLOCAL;
    if (win32()) {
      chomp($TEXMFLOCALVAR =`kpsewhich --expand-path=\$TEXMFLOCAL`);
      @TEXMFLOCAL = map { lc } split(/;/ , $TEXMFLOCALVAR);
    } else {
      chomp($TEXMFLOCALVAR =`kpsewhich --expand-path='\$TEXMFLOCAL'`);
      @TEXMFLOCAL = split /:/ , $TEXMFLOCALVAR;
    }
    #
    # search for TEXMFLOCAL/web2c/$fn
    my @tmlused;
    for my $tml (@TEXMFLOCAL) {
      my $TMLabs = Cwd::abs_path($tml);
      next if (!$TMLabs);
      if (-r "$TMLabs/web2c/$fn") {
        push @tmlused, "$TMLabs/web2c/$fn";
      }
    }
    #
    # user mode (no -sys):
    # ====================
    # TEXMFCONFIG    $HOME/.texliveYYYY/texmf-config/web2c/$fn
    # TEXMFVAR       $HOME/.texliveYYYY/texmf-var/web2c/$fn
    # TEXMFHOME      $HOME/texmf/web2c/$fn
    # TEXMFSYSCONFIG $TEXLIVE/YYYY/texmf-config/web2c/$fn
    # TEXMFSYSVAR    $TEXLIVE/YYYY/texmf-var/web2c/$fn
    # TEXMFLOCAL     $TEXLIVE/texmf-local/web2c/$fn
    # TEXMFDIST      $TEXLIVE/YYYY/texmf-dist/web2c/$fn
    # 
    # root mode (--sys):
    # ==================
    # TEXMFSYSCONFIG $TEXLIVE/YYYY/texmf-config/web2c/$fn
    # TEXMFSYSVAR    $TEXLIVE/YYYY/texmf-var/web2c/$fn
    # TEXMFLOCAL     $TEXLIVE/texmf-local/web2c/$fn
    # TEXMFDIST      $TEXLIVE/YYYY/texmf-dist/web2c/$fn
    #
    @{$opts{'cnffile'}}  = @used_files;
    #
    # determine the config file that we will use for changes
    # if in the list of used files contains either one from
    # TEXMFHOME or TEXMFCONFIG (which is TEXMFSYSCONFIG in the -sys case)
    # then use the *top* file (which will be either one of the two),
    # if none of the two exists, create a file in TEXMFCONFIG and use it
    my $use_top = 0;
    for my $f (@used_files) {
      if ($f =~ m!(\Q$TEXMFHOME\E|\Q$texmfconfig\E)/web2c/$fn!) {
        $use_top = 1;
        last;
      }
    }
    if ($use_top) {
      ($changes_config_file) = @used_files;
    } else {
      # add the empty config file
      my $dn = "$texmfconfig/web2c";
      $changes_config_file = "$dn/$fn";
    }
  }
  if (!$opts{'quiet'}) {
    print "$prg is using the following $fn files (in precedence order):\n";
    for my $f (@{$opts{'cnffile'}}) {
      print "  $f\n";
    }
    print "$prg is using the following $fn file for writing changes:\n";
    print "  $changes_config_file\n";
  }
  if ($opts{'listfiles'}) {
    # we listed it above, so be done
    exit 0;
  }

  $alldata->{'changes_config'} = $changes_config_file;
}



#
# $HOME and sudo and updmap-sys horror
#   some instances of sudo do not reset $HOME to the home of root
#   as an effect of "sudo updmap" creates root owned files in the home 
#   of a normal user, and "sudo updmap-sys" uses map files and updmap.cfg
#   files from the directory of a normal user, but creating files
#   in TEXMFSYSCONFIG. This is *all* wrong.
#   we check: if we are running as UID 0 (root) on Unix and the
#   ENV{HOME} is NOT the same as the one of root, then give a warning
#   and reset it to the real home dir of root.

sub reset_root_home {
  if (!win32() && ($> == 0)) {  # $> is effective uid
    my $envhome = $ENV{'HOME'};
    # if $HOME isn't an existing directory, we don't care.
    if (defined($envhome) && (-d $envhome)) {
      # we want to avoid calling getpwuid as far as possible, so if
      # $envhome is one of some usual values we accept it without worrying.
      if ($envhome =~ m,^(/|/root|/var/root)/*$,) {
        return;
      }
      # $HOME is defined, check what is the home of root in reality
      my (undef,undef,undef,undef,undef,undef,undef,$roothome) = getpwuid(0);
      if (defined($roothome)) {
        if ($envhome ne $roothome) {
          warning("$prg: resetting \$HOME value (was $envhome) to root's "
            . "actual home ($roothome).\n");
          $ENV{'HOME'} = $roothome;
        } else {
          # envhome and roothome do agree, nothing to do, that is the good case
        }
      } else { 
        warning("$prg: home of root not defined, strange!\n");
      }
    }
  }
}

sub print_warning {
  print STDERR "$prg [WARNING]: ", @_ if (!$opts{'quiet'}) 
}
sub print_error {
  print STDERR "$prg [ERROR]: ", @_;
}

sub warning {
  print STDERR @_;
}



# help, version.

sub version {
  my $ret = sprintf "%s version %s\n", $prg, $version;
  return $ret;
}

sub help {
  my $usage = <<"EOF";
Usage: $prg     [OPTION] ... [COMMAND]
   or: $prg-sys [OPTION] ... [COMMAND]
   or: mktexfmt FORMAT.fmt|BASE.base|MEM.mem|FMTNAME.EXT

Rebuild and manage TeX formats, Metafont bases and MetaPost mems.

If the command name ends in mktexfmt, only one format can be created.
The only options supported are --help and --version, and the command
line must consist of either a format name, with its extension, or a
plain name that is passed as the argument to --byfmt (see below).  The
full name of the generated file (if any) is written to stdout, and
nothing else.

If not operating in mktexfmt mode, the command line can be more general,
and multiple formats can be generated, as follows.

Optional behavior:
  --cnffile FILE             read FILE instead of fmtutil.cnf
                             (can be given multiple times, in which case
                             all the files are used)
  --fmtdir DIRECTORY
  --no-engine-subdir         don't use engine-specific subdir of the fmtdir
  --no-error-if-no-format    exit successfully if no format is selected
  --no-error-if-no-engine=ENGINE1,ENGINE2,...
                             exit successfully even if the required engine
                               is missing, if it is included in the list.
  --quiet                    be silent
  --test                     (not implemented, just for compatibility)
  --dolinks                  (not implemented, just for compatibility)
  --force                    (not implemented, just for compatibility)

Valid commands for fmtutil:
  --all                      recreate all format files
  --missing                  create all missing format files
  --refresh                  recreate only existing format files
  --byengine ENGINENAME      (re)create formats using ENGINENAME
  --byfmt FORMATNAME         (re)create format for FORMATNAME
  --byhyphen HYPHENFILE      (re)create formats that depend on HYPHENFILE
  --enablefmt FORMATNAME     enable formatname in config file
  --disablefmt FORMATNAME    disable formatname in config file
  --listcfg                  list (enabled and disabled) configurations,
                             filtered to available formats
  --catcfg                   output the content of the config file
  --showhyphen FORMATNAME    print name of hyphenfile for format FORMATNAME
  --version                  show version information and exit
  --help                     show this message and exit

Explanation of trees and files normally used:

  If --cnffile is specified on the command line (possibly multiple
  times), its value(s) are used.  Otherwise, fmtutil reads all the
  fmtutil.cnf files found by running \`kpsewhich -all fmtutil.cnf', in the
  order returned by kpsewhich.

  In any case, if multiple fmtutil.cnf files are found, all the format
  definitions found in all the fmtutil.cnf files are merged.

  Thus, if fmtutil.cnf files are present in all trees, and the default
  layout is used as shipped with TeX Live, the following files are
  read, in the given order.
  
  For fmtutil-sys:
  TEXMFSYSCONFIG \$TEXLIVE/YYYY/texmf-config/web2c/fmtutil.cnf
  TEXMFSYSVAR    \$TEXLIVE/YYYY/texmf-var/web2c/fmtutil.cnf
  TEXMFLOCAL     \$TEXLIVE/texmf-local/web2c/fmtutil.cnf
  TEXMFDIST      \$TEXLIVE/YYYY/texmf-dist/web2c/fmtutil.cnf

  For fmtutil:
  TEXMFCONFIG    \$HOME/.texliveYYYY/texmf-config/web2c/fmtutil.cnf
  TEXMFVAR       \$HOME/.texliveYYYY/texmf-var/web2c/fmtutil.cnf
  TEXMFHOME      \$HOME/texmf/web2c/fmtutil.cnf
  TEXMFSYSCONFIG \$TEXLIVE/YYYY/texmf-config/web2c/fmtutil.cnf
  TEXMFSYSVAR    \$TEXLIVE/YYYY/texmf-var/web2c/fmtutil.cnf
  TEXMFLOCAL     \$TEXLIVE/texmf-local/web2c/fmtutil.cnf
  TEXMFDIST      \$TEXLIVE/YYYY/texmf-dist/web2c/fmtutil.cnf
  
  (where YYYY is the TeX Live release version).
  
  According to the actions, fmtutil might write to one of the given files
  or create a new fmtutil.cnf, described further below.

Where changes are saved: 

  If config files are given on the command line, then the first one 
  given will be used to save any changes from --enable or --disable.  
  If the config files are taken from kpsewhich output, then the 
  algorithm is more complex:

    1) If \$TEXMFCONFIG/web2c/fmtutil.cnf or \$TEXMFHOME/web2c/fmtutil.cnf
    appears in the list of used files, then the one listed first by
    kpsewhich --all (equivalently, the one returned by kpsewhich
    fmtutil.cnf), is used.
      
    2) If neither of the above two are present and changes are made, a
    new config file is created in \$TEXMFCONFIG/web2c/fmtutil.cnf.
  
  In general, the idea is that if a given config file is not writable, a
  higher-level one can be used.  That way, the distribution's settings
  can be overridden for system-wide using TEXMFLOCAL, and then system
  settings can be overridden again for a particular using using TEXMFHOME.

Resolving multiple definitions of a format:

  If a format is defined in more than one config file, then the definition
  coming from the first-listed fmtutil.cnf is used.

Disabling formats:

  fmtutil.cnf files with higher priority (listed earlier) can disable
  formats mentioned in lower priority (listed later) fmtutil.cnf files by
  writing, e.g.,
    \#! <fmtname> <enginename> <hyphen> <args>
  in the higher-priority fmtutil.cnf file. 

  As an example, suppose you have want to disable the luajitlatex format.
  You can create the file \$TEXMFCONFIG/web2c/fmtutil.cnf with the content
    #! luajitlatex luajittex language.dat,language.dat.lua lualatex.ini
  and call $prg.


MORE DOCUMENTATION STILL TO COME ...

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
