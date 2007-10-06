#!/usr/bin/perl
use strict;
use Irssi qw(command);
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => "simmel\@(undernet|quakenet|freenode)",
        name        => "terminal-app-bugfix",
        description => "Fixes some problems with cmd+doubleclicking URLs in Terminal.app and screen.",
        license     => "BSD",
        url         => "http://soy.se/code/",
    );

foreach ('window changed', 'message private', 'message public')
{
	Irssi::signal_add($_, sub { command("redraw"); });
}
