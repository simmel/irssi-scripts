sub DEBUG () { 0 }

use strict;
use URI::Escape;
use LWP::UserAgent;
use POSIX;
use Irssi qw(settings_add_int settings_add_str settings_add_time settings_get_bool settings_get_int settings_get_str settings_get_time settings_set_time signal_add signal_continue);
if (DEBUG)
{
	use Data::Dumper;
	use warnings;
}

use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => "simmel\@(undernet|quakenet|freenode)",
        name        => "ignoreplace",
        date        => "20070417",
        description => "",
        license     => "BSDw/e, please send bug reports, suggestions, improvements.",
        url         => "http://soy.se/code/",
    );
# README: Read the description above and /set those settings.

# Changelog

# TODO FIXME

# Variables
our @annoyances = ("äg(ig|ande) ");

# Settings

# Signals
signal_add('message public', 'cmd_ignoreplace');

sub cmd_ignoreplace
{
	my ($server, $msg, $nick, $address, $target) = @_;
	for my $annoyance (@annoyances)
	{
		$msg =~ s/$annoyance//g;
	}
	signal_continue($server, $msg, $nick, $address, $target);
}
