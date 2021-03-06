texlive-rewrite
===============

Some of the core scripts of TeX Live are still written in shell, taken from Thomas Esser's teTeX.
Since we would like to have the same scripts used on all supported platforms, that includes Windows,
we are planning to rewrite these scripts in perl or texlua.

Currently only updmap has been rewritten (and extended), but we want to do the same with mktexlsr
and fmtutils, as well as the depending scripts.

Contributions are welcome.
Rewrite of some core scripts in TeX Live from shell to perl

Aims
----

Our aims are:
- use the same scripts on all platforms, not separate implementations
- make each program available as perl function / module and cmd line prog
- separate out the necessary common functions into one file 
  (not TLUtils.pm) so that it can be used in other circumstances, too
  (one selfcontained distribution!)
- add -sys switch to all programs

Scripts involved:
- main scripts (with cmd line interface)
        mktexlsr
        fmtutil
        updmap (partially done)
        texconfig (via wrapper for tlmgr?)
- supporting scripts in texmf-dist/web2c/
        mktex.opt       (a script!)
        mktexdir(.opt)
        mktexnam(.opt)
        mktexupd
- supporting scripts in texmf-dist/texconfig/
        tcfmgr
- supporting scripts in texmf-dist/scripts/texlive/
        kpsetool.sh
        kpsewhere.sh
        texlinks.sh


mktexlsr/mktexupd
-----------------

help output
-----------
Rebuild ls-R filename databases used by TeX.  If one or more arguments
DIRS are given, these are used as the directories in which to build
ls-R. Else all directories in the search path for ls-R files
($TEXMFDBS) are used.

~~~~~
Options:
  --dry-run  do not actually update anything
  --help     display this help and exit 
  --quiet    cancel --verbose
  --silent   same as --quiet
  --verbose  explain what is being done
  --version  output version information and exit
~~~~~
	      
If standard input is a terminal, --verbose is on by default.

mktexupd
--------
adds entries without reading the rest of the tree


Operation of mktexlsr:
----------------------
- cmd line options
- get list of trees to rebuild:
	cmd line
	kpsewhich --show-path=ls-R | tr : '\n' or so
		(why not kpsewhich -var-value TEXMFDBS?)
- for each tree
  . make it absolute tree
  . check for ls-R versus ls-r, use what is there, or create ls-R
  . get link target if it is a link
  . use kpsestat and chmod to change permissions of new file according
    to the upper level dir
  . check for magic string (new and old)
  . check for writability
  . add toplevel ./: at top
  . run ls -LRa and do some sed magic
    remove empty parts, remove VCS dirs


perl option:
------------
use File::Find (core module)

	find(\&wanted, @directories)




