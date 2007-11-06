sub DEBUG () { 1 }
use strict;
no strict 'refs';
use LWP::Simple;
use Irssi;
use Encode;
use HTML::Entities;
use POSIX qw(strftime);
if (DEBUG)
{
	use Data::Dumper;
	use warnings;
}

use vars qw($VERSION %IRSSI);
our ($pid, $input_tag) = undef;

$VERSION = "3.3";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => 'simmel@(undernet|quakenet|freenode)',
        name        => "lastfm",
        date        => "20071024",
        description => 'Show with /np or $np<TAB> what song "lastfm_user" last submitted to Last.fm via /me, if "lastfm_use_action" is set, or /say (default) with an configurable message, via "lastfm_sprintf" with option to display a when it was submitted with "lastfm_strftime". Turning on "lastfm_be_accurate_and_slow" enables more accurate results but is *very* slow.',
        license     => "BSDw/e, please send bug-reports, suggestions, improvements.",
        url         => "http://soy.se/code/",
    );
# README: Read the description above and /set those settings (the ones quoted with double-quotes). Scroll down to Settings for a more information about the settings.

# TODO
# * Fix better error reporting. SERIOUSLY, DOIT! http://perldesignpatterns.com/?ErrorReporting maybe?
# * Fallback for accurate_and_slow to normal if nothing is "now playing" but recently <30min. Maybe irritating? Make it a setting?

# Changelog

# 3.3 --
# * Finally added conditional sprintf-syntax! Let's say you want to use 'np: %s-%s (%s)' as "lastfm_sprintf". If you use /np it works out fine and displays 'np: Boards of Canada-Energy Warning (Geogaddi)' but what if you use /np! then it displays 'np: Boards of Canada-Energy Warning ()' since /np! can't get the album information. Doesn't that look ugly? Meet conditional sprintf. Now set your "lastfm_sprintf" to 'np: %s-%s%( (%s))'. ' (%s)' will only be printed if we get a third value, the album name in this case. Smart, huh? Big thanks to rindolf, apeiron and Khisanth from #perl@freenode for help with scoping with global variables.
# * Also added "lastfm_sprintf_tab_complete" which makes, if set, $np<TAB> use a different sprintf pattern than /np. Will default back to "lastfm_sprintf".

# 3.2 -- Wed Oct 24 23:07:01 CEST 2007
# * I don't like dependencies and I really wonder why I lastfm depended on DateTime. I remember now that it was morning and I was really tired when I coded it. Anyway, it's removed now along with Socket and URI::Escape. I'll try to remove the dependency for libwww later on.

# 3.1 -- Sun Oct 21 22:52:36 CEST 2007
# * Added /np! and $np! to use the "lastfm_be_accurate_and_slow" method without having to change the setting.

# 3.0 -- Fri Oct 19 14:26:03 CEST 2007
# * Created a new setting "lastfm_be_accurate_and_slow" which makes lastfm.pl parse your profile page to check what song you are playing right now. But be warned, this is slow and horrible (like my code! ; ). But it works until Last.fm makes this data available through their Web Services. This disables the album and "scrobbled at" features of "lastfm_sprintf" so you have to adapt it if you don't want it to look weird. I'm working on a new implementation of printf which allows for conditions but it took more time than I thought and time is something that I don't have much of ='(

# 2.5 -- Tue Oct  9 11:29:56 CEST 2007
# * Fixed the encoding issue by converting from Last.fms UTF-8 into Perls internal encoding. With $np<TAB> output will be looking UTF-8-in-latin1 if you don't have an UTF-8 enabled Terminal, but it will display correctly after you have sent it.

# 2.4 -- Mon Oct  8 16:08:09 CEST 2007
# * Fixed an error in error reporting ; P Bug noticed by supertobbe = *
# * I should make an more generic and better error reporting.

# 2.3 -- Sat Oct  6 16:38:34 CEST 2007
# * Made /np a nonblocking operation. Irssi's fork handling is REALLY messy. Thanks to tss and tommie for inspiring me in their scripts. $np cannot be made nonblocking, I'm afraid (patches welcome).
# * Cleaned up abit.

# 2.2 -- Sat Aug 18 02:20:44 CEST 2007
# * Now you can use $np(darksoy) to see what I play (or someone else for that matter ; ).

# 2.1 -- Tue Jul 17 12:50:18 CEST 2007
# * Now you can use $np or $nowplaying as a tab-completion too, but a warning here, this is a blocking action so irssi won't respond or be usable until it is finished or the timeout is hit.
# * Abstracted it abit more so that it can be used in more ways, ex. for the reason above.

# 2.0 -- Fri Jun 29 10:38:32 CEST 2007
# * Now you can show the time that the song was submitted in lastfm_sprintf. Added lastfm_strftime to configure how the date is presented.
# * Added $lastfm and $lfm as tab-completions to your own Last.fm profile URL. Ripoff of Jured's guts.pl (http://juerd.nl/irssi/)

# 1.5 -- Sat May 12 03:30:24 CEST 2007
# * Started using XML instead because we get more info from it, like album (but it's often wrong).

# 1.0 -- Thu Apr 12 16:57:26 CEST 2007
# * Got fedup with no good Last.fm-based now playing scripts around.

# Settings
# The username which you are using on Last.fm
Irssi::settings_add_str("lastfm", "lastfm_user", "");

# The printf-string that you want to use.
# There are four %s's that you can use at the moment. They represent:
# 1, Artist
# 2, Title of the song
# 3, Title of the album
# 4, The time it was submitted, configurable via lastfm_strftime
# For example: "np: %s-%s" expands to "np: The Prodigy-You'll be under my wheels".
# See printf(3) for more information.
# If you want to change the order, use %2$s to get the second arg.
Irssi::settings_add_str("lastfm", "lastfm_sprintf", 'np: %s-%s');
Irssi::settings_add_str("lastfm", "lastfm_sprintf_tab_complete", '');

# The strftime(3) syntax used when displaying at what time a song was submitted.
Irssi::settings_add_str("lastfm", "lastfm_strftime", 'submitted at: %R %Z');

# If we should use /me instead of /say
Irssi::settings_add_bool("lastfm", "lastfm_use_action", 0);

# Parse the profile instead, gets accurate data but is *much* slower.
Irssi::settings_add_bool("lastfm", "lastfm_be_accurate_and_slow", 0);

# Move along now, there's nothing here to see.

my $errormsg_pre = "You haven't submitted a song to Last.fm";
my $errormsg_post = ", maybe Last.fm submission service is down?";

sub cmd_lastfm
{
	my ($data, $server, $witem) = @_;
	lastfm_forky($witem);
}
sub cmd_lastfm_now
{
	my ($data, $server, $witem) = @_;
	my $setting = Irssi::settings_get_bool("lastfm_be_accurate_and_slow");
	Irssi::settings_set_bool("lastfm_be_accurate_and_slow", 1);
	lastfm_forky($witem);
	Irssi::settings_set_bool("lastfm_be_accurate_and_slow", $setting);
}

sub lastfm
{
		my $content;
		my $url;
		my $alt;
		my $user = shift || Irssi::settings_get_str("lastfm_user");
		my $strftime = Irssi::settings_get_str("lastfm_strftime");
		my @caller = caller(1);
		my $is_tabbed = ($caller[3] eq "Irssi::Script::lastfm::lastfm_forky") ? 0 : 1;
		my $sprintf = (Irssi::settings_get_str("lastfm_sprintf_tab_complete") ne "" && $is_tabbed) ? Irssi::settings_get_str("lastfm_sprintf_tab_complete") : Irssi::settings_get_str("lastfm_sprintf");

		#Sanity checking#{{{
		if ($user eq "")
		{
			Irssi::active_win()->print("You must /set lastfm_user to an username on Last.fm");
			return;
		}

		if (Irssi::settings_get_bool("lastfm_be_accurate_and_slow"))
		{
			$url = "http://www.last.fm/user/$user";
		}
		else
		{
			$url = "http://ws.audioscrobbler.com/1.0/user/$user/recenttracks.xml";
		}
		$content = get($url);

		if (!defined $content)
		{
			Irssi::active_win()->print("Last.fm is probably down or maybe you have set lastfm_user (currently set to: $user) to an non-existant user.");
			return;
		}#}}}

		if (Irssi::settings_get_bool("lastfm_be_accurate_and_slow") && $content =~ m!nowListening.*?\<a.*?>(.+?)<\/a>.*?<a.*?>(.+?)<\/a>!s)
		{
		}
		elsif ($content =~ m!<artist [^>]+>\s*?(.+?)\s*?</artist>\s+<name>\s*?(.+?)\s*?</name>.+?<album .+?>(.*?)(?:</album>)?\n.+?<date uts="(\d+)"!s)
		{
		}

		print Dumper $1, $2, $3, $4 if DEBUG;
		if ($1 eq "")
		{
			return "error:" if (!$is_tabbed);
			$alt = " yet";
			Irssi::active_win()->print($errormsg_pre.$alt.$errormsg_post);
			return;
		}

		if ($4 ne "")
		{
			if ($4 < strftime('%s', localtime()) - 60 * 30)
			{
				return "error:time" if (!$is_tabbed);
				$alt = " within the last 30 minutes";
				Irssi::active_win()->print($errormsg_pre.$alt.$errormsg_post);
				return;
			}
			$strftime = strftime($strftime, localtime(scalar($4)));
		}
		else
		{
			undef $strftime;
		}
		$content = sprintfng($sprintf, $1, $2, $3, $strftime);
		$content = Encode::decode('utf-8', $content);
		decode_entities($content);
		return $content;
}

sub lastfm_forky
{
	my $witem = shift;
	if ($pid or $input_tag)
	{
		Irssi::active_win()->print("We're still waiting for Last.fm to return our data or to hit the timeout (this happends when Last.fm is down or very slow).");
		return;
	}

	my ($reader, $writer);
	pipe($reader, $writer);
	$pid = fork();
	return unless ( defined $pid );
	if ($pid)
	{
		close($writer);
		Irssi::pidwait_add($pid);
		my @args = ($witem, $reader);
		$input_tag = Irssi::input_add(fileno($reader), INPUT_READ, \&input_read, \@args);
	}
	else
	{
		close($reader);
		print $writer lastfm();
		close($writer);
		POSIX::_exit(1);
	}
}

sub input_read {
	my ($witem, $reader) = @{$_[0]};
	my @content = <$reader>;
	my $content = join('', @content);

	if ($content eq "error:time")
	{
		Irssi::active_win()->print($errormsg_pre." within the last 30 minutes".$errormsg_post);
	}
	elsif ($content eq "error:")
	{
		Irssi::active_win()->print($errormsg_pre.$errormsg_post);
	}
	else
	{
		if (defined $witem->{type} && $witem->{type} =~ /^QUERY|CHANNEL$/)
		{
			if (Irssi::settings_get_bool("lastfm_use_action"))
			{
				$witem->command("me $content");
			}
			else
			{
				$witem->command("say $content");
			}
		}
		else
		{
			print($content);
		}
	}

	Irssi::input_remove($input_tag);
	close($reader);
	$input_tag = $pid = undef;
}

sub sprintfng
{
	my ($pattern, @args) = @_;
	my $argc = scalar(grep(/./, @args));
	my $format_chars = () = $pattern =~ /%\w/g;

	my $count = ($format_chars > $argc) ? $argc : $format_chars;

	print Dumper "argc=$argc, format_chars=$format_chars, count=$count" if DEBUG;
	print Dumper "före checkifexists: $pattern" if DEBUG;
	$pattern =~ s/(%\(.*?\)\)*|%\w)/checkifexists($1, $count, $format_chars)/eg;
	print Dumper "efter checkifexists: $pattern" if DEBUG;
	sprintf($pattern, @args);
}

{
	my $i=0;
	sub checkifexists
	{
		$i++;
		my ($condition, $count, $count_max) = @_;

		print "$i vs count: $count max:$count_max \n" if DEBUG;
		print "pattern: $condition\n" if DEBUG;
		if ($i > $count)
		{
			print "undef\n" if DEBUG;
			$condition = undef;
		}
		if ($i == $count_max)
		{
			print "resetting \$i\n" if DEBUG;
			$i=0;
		}
		$condition =~ s/%\((.*)\)*/$1/g;
		return $condition;
	}
}

Irssi::command_bind('np', 'cmd_lastfm', 'lastfm');
Irssi::command_bind('np!', 'cmd_lastfm_now', 'lastfm');

Irssi::signal_add_last 'complete word' => sub {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	if ($word =~ /\$(lastfm|lfm)/)
	{
		my $user = Irssi::settings_get_str("lastfm_user");
		if ($user eq "")
		{
			Irssi::active_win()->print("You must /set lastfm_user to an username on Last.fm");
			return;
		}
		push @$complist, "http://last.fm/user/$user/";
	}
	elsif ($word =~ /\$(?:nowplaying|np)(!*)\(?(\w+)?\)?/)
	{
		my $setting;
		if ($1)
		{
			$setting = Irssi::settings_get_bool("lastfm_be_accurate_and_slow");
			Irssi::settings_set_bool("lastfm_be_accurate_and_slow", 1);
		}
		my $nowplaying = lastfm($2);
		if ($1)
		{
			Irssi::settings_set_bool("lastfm_be_accurate_and_slow", $setting);
		}
		push @$complist, "$nowplaying" if $nowplaying;
	}
}
