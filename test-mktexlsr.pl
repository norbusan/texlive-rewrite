#!/usr/bin/env perl
#

use strict;
$^W = 1;

require "mktexlsr.pl";
require Data::Dumper;
$Data::Dumper::Indent = 1;

  chomp (my $t = `kpsewhich -var-value TEXMFDIST`);
  my $lsr = new TeX::LSR(root => $t);
  if ($lsr->loadtree()) {
    chomp (my $outi = `mktemp ls-R.test1.XXXXXXXX`);
    $lsr->write(filename => $outi, sort => 1);
    print "Test 1 : load TEXMFDIST with loadtree, write lsr to $outi\n";
    chomp ($outi = `mktemp ls-R.test2.XXXXXXXX`);
    open OUT, ">$outi";
    print OUT Data::Dumper->Dumper($lsr);
    close OUT;
    print "Test 2 : load TEXMFDIST with loadtree, Dumper to $outi\n";
  } else {
    print "Cannot loadtree from $t!\n";
  }
  $lsr = new TeX::LSR(root => $t);
  if ($lsr->loadfile()) {
    chomp (my $outi = `mktemp ls-R.test3.XXXXXXXX`);
    $lsr->write(filename => $outi, sort => 1);
    print "Test 3 : load TEXMFDIST with loadfile, write lsr to $outi\n";
    chomp ($outi = `mktemp ls-R.test4.XXXXXXXX`);
    open OUT, ">$outi";
    print OUT Data::Dumper->Dumper($lsr);
    close OUT;
    print "Test 4 : load TEXMFDIST with loadfile, Dumper to $outi\n";
    $lsr->addfiles("bibtex/bib/beebe/foobar", "bibtex/bib/emil/detektive", "foo/bar/baz", "brrrrrr");
    chomp ($outi = `mktemp ls-R.test5.XXXXXXXX`);
    $lsr->write(filename => $outi, sort => 1);
    print "Test 5 : load TEXMFDIST with loadfile, add file, write lsr to $outi\n";
  } else {
    print STDERR "Cannot loadfile from $t!\n";
  }


### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
