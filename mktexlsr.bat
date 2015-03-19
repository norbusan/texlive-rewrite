@echo off
rem Launcher for mktexlsr perl script
rem
rem Public Domain
rem Originally written 2009 by Tomasz M. Trzeciak

rem Make environment changes local
setlocal enableextensions

rem Get TL installation root (w/o trailing backslash)
set tlroot=%~dp0:
set tlroot=%tlroot:\bin\win32\:=%

rem Start mktexlsr
set PERL5LIB=%tlroot%\tlpkg\tlperl\lib
path %tlroot%\tlpkg\tlperl\bin;%tlroot%\bin\win32;%path%
"%tlroot%\tlpkg\tlperl\bin\perl.exe" "%tlroot%\texmf-dist\scripts\texlive\mktexlsr.pl" %*

