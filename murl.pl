sub DEBUG () { 0 }

use strict;
use URI::Escape;
use LWP::UserAgent;
use POSIX;
use Irssi qw(active_win command command_bind settings_add_bool settings_add_int settings_add_str settings_add_time settings_get_bool settings_get_int settings_get_str settings_get_time settings_set_time signal_add signal_continue timeout_add timeout_remove);
if (DEBUG)
{
	use Data::Dumper;
	use warnings;
}

use vars qw($VERSION %IRSSI);

$VERSION = "2.0";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => "simmel\@(undernet|quakenet|freenode)",
        name        => "murl",
        date        => "20070417",
        description => "If murl_auto is enabled, it automatically replaces URLs that are longer than murl_max_len with an shorter using murl.(se|info) and tries murl_retries with an timeout of murl_timeout with an optional murl_ignore_regex to ignore some urls. Also provides /murl command.",
        license     => "BSDw/e, please send bug reports, suggestions, improvements.",
        url         => "http://soy.se/code/",
    );
# README: Read the description above and /set those settings.

# Thanks to:
# * Rado@#irssi:freenode for perldoc perlre \Q s/\Q$url\E/$murl/g
# * yrlnry@#perl:freenode for s/(url)/getMurl($1)/ge
# * inMute@#irssi:freenode for helping with debuging and suggestions


# Changelog
# 2.0 -- Tue Apr 17 20:11:25 CEST 2007
# * Added setting murl_auto which allows to turn automatic murling off.
# * Added command /murl to be able to murl manually.

# 1.9 -- Sat Mar 17 22:34:31 CET 2007
# * Fix a setting which doesnt create murls in some channels/queries

# 1.8 -- Sat Mar 17 01:08:35 CET 2007
# * Fix so that pastings of the same url won't be double posted.

# TODO FIXME
# * Fix sub dnslookup to have an working resolver fork implementation, currently using /exec host murl.se
# * Sometimes irssi just freezes and takes FOREVER to run the script, I have no idea why. Happends like once a week or so. Does this happend to you? I belive this has been fixed.


# Variables
my $cachetimer;
my $times;
my $count;
my $return;
my $murled;
our %murls;

# Settings
settings_add_bool("murl", "murl_dns_recache", 0);
settings_add_bool("murl", "murl_auto", 1);
settings_add_time("murl", "murl_dns_recache_interval", 300);
settings_add_int("murl", "murl_max_len", 50);
settings_add_time("murl", "murl_timeout", 2);
settings_add_int("murl", "murl_retries", 3);
settings_add_str("murl", "murl_ignore_regex", "validator\.w3\.org");
settings_add_str("murl", "murl_ignore_channels", 'channel@network channel:network');

# Signals
signal_add("setup changed", \&event_setup_changed);
signal_add('send text', 'cmd_catchtext');

# Structure
sub UNLOAD
{
	remove_cache_timer();
}

# LOAD kindof
event_setup_changed();

sub event_setup_changed
{
	if (settings_get_time("murl_dns_recache_interval") < 30000)
	{
		print "murl_dns_recache_interval can't be cleared or put below 30s, setting it to default.";
		settings_set_time("murl_dns_recache_interval", 300);
	} 
	elsif (settings_get_bool("murl_dns_recache") == 1)
	{
		add_cache_timer();
	}
	elsif (settings_get_bool("murl_dns_recache") == 0)
	{
		remove_cache_timer();
	}
}

# Functions

sub reportbug($)
{
	my ($msg) = @_;
	print "Please report this bug to the author via $IRSSI{contact}";
	print $msg;
}

sub dnslookup
{
# TODO FIXME
# Use this instead, but I can't get it to work. It works as an perl script but
# within irssi it just goes crazy with the windows. In perl $pid = 0 as it
# should be but in irssi it's _ALWAYS_ >0.

#	my $pid = fork();/*{{{*/
#	if (not defined $pid)
#	{
#		reportbug("Resources not avilable.");
#	}
#	elsif ($pid == 0)
#	{
#		my $command = `host murl.se`;
#		if ($? != 0)
#		{
#			if ($? == -1)
#			{
#				reportbug("Failed to execute: $!");
#			}
#			elsif ($? & 127)
#			{
#				my $signal = ($? & 127);
#				my $word = ($? & 128) ? 'with' : 'without';
#				reportbug("Child died with signal ${signal}, $word coredump");
#			}
#		}
#		POSIX::_exit(0);
#	}/*}}}*/

# I'm using this dirty hack instead.
	command("/exec - host murl.se 1>/dev/null");
}

sub add_cache_timer
{
	DEBUG && print "Start re-cacheing";
	my $time = settings_get_time("murl_dns_recache_interval");
	$cachetimer = timeout_add($time, \&dnslookup, "heij");
}

sub remove_cache_timer
{
	return 1 if (!defined $cachetimer);
	timeout_remove($cachetimer);
	undef $cachetimer;
	DEBUG && print "Removed cache timer.";
}

sub cmd_catchtext
{
	return if !settings_get_bool("murl_auto");
	my ($line, $server, $witem) = @_;
	$line =~ s#(https?://\S+)#getMurl($1, $witem)#ge;
#	Old regex: s/(https*:\/\/[^ ]+)/getMurl($1)/ge;
	DEBUG && print "We are in cmd_catchtext now atleast.";
	DEBUG && print "\$murled = $murled";
	if ($murled)
	{
		DEBUG && print "Something is murled.";
#		Irssi::signal_stop();
#		Irssi::signal_remove('send text', 'cmd_catchtext');
#		Irssi::signal_emit('send text', $line, $server, $witem);
#		Irssi::signal_add('send text', 'cmd_catchtext');
		signal_continue($line, $server, $witem);
	}
	undef $murled;
}

sub getMurl
{
	my ($url, $witem) = @_;
	# Don't use murl channels listed in murl_ignore_channels
	my ($channel, $network) = ($witem->{name}, $witem->{server}->{chatnet});
	my @channels = split(/ /, settings_get_str("murl_ignore_channels"));
	return if grep (/^$channel[:@]$network$/i, @channels);

	$times = settings_get_int("murl_retries");
	my $regex = settings_get_str("murl_ignore_regex");
	if (length($url) < settings_get_int("murl_max_len") || $url =~ /$regex/) { return $url; }
	if (!defined $count) {
		DEBUG && print "\$count not defined.\n";
		$count++;
	}
	if ($count > $times)
	{
		DEBUG && print "Let's return: ${url}\n";
		return $url;
	}
	DEBUG && print "${count} time in loop.\n";

	# Let's return if we already murled it before.
	if (defined $murls{$url})
	{
		$murled = 1;
		return $murls{$url};
	}

	$url = uri_escape($url);
	my $ua = LWP::UserAgent->new(timeout => settings_get_time("murl_timeout"), agent => "murl.pl $VERSION $IRSSI{date}");
	my $resp = $ua->request(HTTP::Request->new('GET', "http://murl.se/short.php?u=$url&short=1"));
	if ($resp->is_success && $resp->content =~ m#^http://murl.se/(\d+)#i)
	{
		DEBUG && print "\$return IS definied\n";
		$murled = 1;
		$url = uri_unescape($url);
		$murls{$url} = $resp->content;
		return $resp->content;
	}
	else
	{
		DEBUG && print "murl not working, sleeping because this is the $count time";
		DEBUG && print "sleeping ", settings_get_time("murl_timeout"), "\n";
		$count++;
		getMurl($url, $witem);
# Not needed any more since UserAgent has it's own timeout.
#		Irssi::timeout_add_once(Irssi::settings_get_time("murl_timeout"), \&getMurl, $url);
	}
}

# Commands

# Command binds

command_bind('murl', 'cmd_murl');

# Commands subroutines
sub cmd_murl
{
	my ($data, $server, $witem) = @_;
	active_win()->print(getMurl($data, $witem));
}
