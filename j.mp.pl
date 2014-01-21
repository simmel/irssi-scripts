# http://code.google.com/p/bitly-api/wiki/ApiDocumentation
#http://api.bit.ly/v3/shorten?longUrl=http%3A%2F%2Fsoy.se&format=txt&login=simmel&apiKey=R_08afb97102eb0931cee3e9b2a364054b
sub DEBUG () { 1 }

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

$VERSION = "1.0";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => "simmel\@(undernet|quakenet|freenode) or simmel\@soy.se",
        name        => "j.mp",
        date        => "20101117",
        description => "If j.mp_auto is enabled, it automatically replaces URLs that are longer than j.mp_min_url_length with an shorter using http://j.mp with an timeout of j.mp_timeout with an optional j.mp_ignore_regex to ignore some urls. Also provides /j.mp command.",
        license     => "ISC",
        url         => "http://soy.se/code/",
    );
# README: Read the description above and /set those settings.

# Thanks to:
# * Rado@#irssi:freenode for perldoc perlre \Q s/\Q$url\E/$murl/g
# * yrlnry@#perl:freenode for s/(url)/getMurl($1)/ge
# * inMute@#irssi:freenode for helping with debuging and suggestions

# Changelog
# 1.0 -- Sun Jan 17 11:43:42 CET 2010
# * Based on my murl.pl which never was released.

# TODO FIXME
# * Fix sub dnslookup to have an working resolver fork implementation, currently using /exec host j.mp (not even that)
# * Sometimes irssi just freezes and takes FOREVER to run the script, I have no idea why. Happends like once a week or so. Does this happend to you? I belive this has been fixed.

# Variables
my $cachetimer;
our %jmped;

# Settings
settings_add_bool("j.mp", "j.mp_dns_recache", 0);
settings_add_bool("j.mp", "j.mp_auto", 1);
settings_add_time("j.mp", "j.mp_dns_recache_interval", 300);
settings_add_int("j.mp", "j.mp_min_url_length", 50);
settings_add_time("j.mp", "j.mp_timeout", 2);
settings_add_str("j.mp", "j.mp_ignore_regex", "validator\.w3\.org|open.spotify.com");
settings_add_str("j.mp", "j.mp_ignore_channels", 'channel@network channel:network');

# Signals
#signal_add("setup changed", \&event_setup_changed);
signal_add('send text', 'cmd_catchtext');

# Structure
#sub UNLOAD
#{
#	remove_cache_timer();
#}

# LOAD kindof
#event_setup_changed();

#sub event_setup_changed
#{
#	if (settings_get_time("j.mp_dns_recache_interval") < 30000)
#	{
#		print "j.mp_dns_recache_interval can't be cleared or put below 30s, setting it to default.";
#		settings_set_time("j.mp_dns_recache_interval", 300);
#	} 
#	elsif (settings_get_bool("j.mp_dns_recache") == 1)
#	{
#		add_cache_timer();
#	}
#	elsif (settings_get_bool("j.mp_dns_recache") == 0)
#	{
#		remove_cache_timer();
#	}
#}

# Functions

sub reportbug($)
{
	my ($msg) = @_;
	active_win()->print("Please report this bug to the author via $IRSSI{contact}");
	active_win()->print($msg);
}

#sub dnslookup
#{
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
#		my $command = `host j.mp`;
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
#	command("/exec - host j.mp 1>/dev/null");
#}

#sub add_cache_timer
#{
#	DEBUG && print "Start re-cacheing";
#	my $time = settings_get_time("j.mp_dns_recache_interval");
#	$cachetimer = timeout_add($time, \&dnslookup, "heij");
#}

#sub remove_cache_timer
#{
#	return 1 if (!defined $cachetimer);
#	timeout_remove($cachetimer);
#	undef $cachetimer;
#	DEBUG && print "Removed cache timer.";
#}

sub cmd_catchtext
{
	return if !settings_get_bool("j.mp_auto");
	my ($line, $server, $witem) = @_;
	$line =~ s#(https?://\S+)#shorten_url($1, $witem)#ge;
  signal_continue($line, $server, $witem);
}

sub shorten_url
{
	my ($url, $witem) = @_;
	# Don't use j.mp channels listed in j.mp_ignore_channels
	my ($channel, $network) = ($witem->{name}, $witem->{server}->{chatnet});
	my @channels = split(/ /, settings_get_str("j.mp_ignore_channels"));
	return $url if grep (/^$channel[:@]$network$/i, @channels);

	my $regex = settings_get_str("j.mp_ignore_regex");
	if (length($url) < settings_get_int("j.mp_min_url_length") || $url =~ /$regex/) { return $url; }

	# Let's return if we already murled it before.
	if (defined $jmped{$url})
	{
		return $jmped{$url};
	}

	my $escaped_url = uri_escape($url);
	my $ua = LWP::UserAgent->new(timeout => settings_get_time("j.mp_timeout"), agent => "$IRSSI{name}.pl ${VERSION}($IRSSI{date}) $IRSSI{url}");
  my $domain = "j.mp";
	my $resp = $ua->request(HTTP::Request->new('GET', "http://api.bit.ly/v3/shorten?longUrl=$escaped_url&format=txt&login=simmel&apiKey=R_08afb97102eb0931cee3e9b2a364054b&domain=$domain"));
	if ($resp->is_success && $resp->content =~ m#^http://$domain/(.*)#i)
	{
		DEBUG && print "we got an 200 and the response includes $domain!";
    my $jmp_url = $resp->content;
    chomp($jmp_url);
		$jmped{$url} = $jmp_url;
		return $jmp_url;
	}
	else
	{
    reportbug("Can't jump that URL: ".$resp->code." ".$resp->content);
    if (DEBUG) {
      print Dumper \$resp;
      print Dumper $resp->content;
    }
    return $url;
	}
}

# Commands

# Command binds

command_bind('j.mp', 'cmd_jmp');

# Commands subroutines
sub cmd_jmp
{
	my ($data, $server, $witem) = @_;
	active_win()->print(shorten_url($data, $witem));
}
