use vars qw($VERSION %IRSSI);
$VERSION = "4.3";
%IRSSI = (
        authors     => "Simon 'simmel' Lundstr�m",
        contact     => 'simmel@(freenode|quakenet|efnet)',
        name        => "lastfm",
        date        => "20080721",
        description => 'An now-playing-script which uses Last.fm',
        license     => "BSD",
        url         => "http://soy.se/code/",
);
# USAGE
# For details on how to use each setting, scroll down to the SETTINGS section.

# * Show with /np or %np<TAB> what song "lastfm_user" last scrobbled to Last.fm via /say. If "lastfm_use_action" is set, it uses /me.
# * To see what another user on Last.fm is playing is also possible via /np <username> or %np(<username>).
# The now-playing message is configurable via via "lastfm_output" (and lastfm_output_tab_complete when using %np). "lastfm_strftime" can be used to configure the display of date and time when the song was scrobbled.

# Right now lastfm.pl depends on LWP::Simple, but hopefully this will change in the future. The package in your package system is probably called something with libwww and perl and/or p5 in it.

# SETTINGS
# NOTE: Do not set these options here, use /set <option> <value> in irssi!
# These are just defaults and descriptions on what the options do.

# The username which you are using on Last.fm
Irssi::settings_add_str("lastfm", "lastfm_user", "");

# The output that you want to use.
# The substitution variables are:
#   %artist = Self explanatory
#   %album  = Self explanatory
#   %name   = Name of song*
#   %date   = Time when playing of track started, configurable via "lastfm_strftime"
#   %url    = URL to song on Last.fm
# If "lastfm_output_tab_complete" is not defined, "lastfm_output" will be used instead.
#  *) Name is used instead of, the more logical IMO, track since that is what Last.fm reports in their .xml file that we parse.
Irssi::settings_add_str("lastfm", "lastfm_output", 'np: %artist-%name');
Irssi::settings_add_str("lastfm", "lastfm_output_tab_complete", '');

# The strftime(3) syntax used when displaying at what time a song was submitted.
Irssi::settings_add_str("lastfm", "lastfm_strftime", 'scrobbled at: %R %Z');

# If we should use /me instead of /say
Irssi::settings_add_bool("lastfm", "lastfm_use_action", 0);

# To use the "lastfm_debug" setting you'll need to install the Data::Dumper CPAN plugin.

# Changelog#{{{

# 4.4 -- 
# * Changed so that all the tab-commands use % instead of $ so that it's consistent through out the script.
# * Ripped out my sprintf crap and made it more sane. You should use %artist, %album, etc in your nowplaying-setting now. Since sprintf is nolonger used I renamed that setting too.
# * Made everything that you can set in "lastfm_output" tabable so now you can do %artist<TAB>.

# 4.3 -- Mon 21 Jul 2008 08:46:36 CEST
# * Seem like I misunderstood the protocol. The date/time is only sent when we have scrobbled the track, not when we started to listen to it.

# 4.2 -- Tue 15 Jul 2008 15:40:08 CEST
# Yay! Three new version within a day! (No, I'm not bored at work)
# * Made /np username and $np(username) make username the prefix of np: yadayada or whatever your lastfm_sprintf or lastfm_sprintf_tab_complete is.

# 4.1 -- Tue 15 Jul 2008 15:23:03 CEST
# Well, that version lasted long!
# * Fixed a bug with /np not working.
# * Fixed an issue where debug info would be printed even if lastfm_debug was off.

# 4.0 -- Tue 15 Jul 2008 10:17:51 CEST
# * Fixing a sprintfng-bug which didn't display time if album was not set.
# * Rewrote the whole script to use Last.fm's API which is very accurate. There is no need for $np! and /np! now, so I'm removing them.
# * Cleaned up abit.

# 3.9 -- Fri 11 Jul 2008 21:49:20 CEST
# * Fixing a few bugs noticed by supertobbe

# 3.8 -- Fri 11 Jul 2008 18:21:52 CEST
# * Shaped up error handling and now all error messages are shown.
# * Added a user configurable debug mode, good for sending in bugs and weird behaviour.
# * Minor cleanup

# 3.7 -- Thu 22 May 2008 10:33:55 CEST
# * Fixed so that /np! and $np! fetches the album title too. This is horribly slow and takes approx. 6s on very fast connection. Last.fm isnt very fast I'm afraid and this is not a good way to do it.
# * Cleaned up a few places. Started to look at the error handling and it seems to be alot of work.

# 3.6 -- Tue Nov 13 15:22:37 CET 2007
# * Fixed encoding so that it always the data into the charset that you have specified in "term_charset" which irssi also uses.

# 3.5 -- Mon Nov 12 11:50:46 CET 2007
# * Fixed the regex for parsing Recently Listened Tracks so that it works when listening with the Lastfm client.

# 3.4 -- Fri Nov  9 00:23:40 CET 2007
# * Added /np lastfmusername

# 3.3 -- Tue Nov  6 01:54:59 CET 2007
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
# * Got fedup with no good Last.fm-based now playing scripts around.#}}}

# Move along now, there's nothing here to see.

sub DEBUG {
	# Enable debug output.
	Irssi::settings_add_bool("lastfm", "lastfm_debug", 0);
	Irssi::settings_get_bool("lastfm_debug");
};

use strict;
no strict 'refs';
use LWP::Simple;
use Irssi;
use Encode;
use POSIX qw(strftime);
if (DEBUG) {
	use Data::Dumper;
	use warnings;
}

# TODO
# * Get rid of LWP::Simple dependency.
# * When np fails, check http://status.last.fm/ if they really are down.
# 	If parsing or getting fails, head status page and check if etag is the same.
# * Fix so that %( %album) works again, help please!
# 1207.29 )( tAnk__ [tank@the.matrix.has-you.net]
# 1207.29 )(  ircname  : tAnk inside the Matrix
# 1207.29 )(  server   : irc.efnet.ru (the peace maker - www.verdure.ru)
# 1207.29 )(           : 83.97.98.215 :actually using host
# 1207.29 )(  idle     : 0 days 0 hours 14 mins 49 secs (signon: Fri Aug 29 
#                        12:02:15 2008)
# * Redo the time since we scrobbled check to say: "This was scrobbled X minutes ago, so this might not be accurate." But the date is when the track started to be played not when we finished it..
# date in sub lastfm is definitely not working.
# Cache output. This requires HEAD and Etag-support though.

my $errormsg_pre = "You haven't submitted a song to Last.fm";
my $errormsg_post = ", maybe Last.fm submission service is down?";
our ($pid, $input_tag) = undef;
my $api_key = "eba9632ddc908a8fd7ad1200d771beb7";
my $fields = "(artist|name|album|date|url)";

sub print_raw {
	my $data = join('', @_);
	$data =~ s/%/%%/g;
	print $data;
}

sub cmd_lastfm {
	my ($data, $server, $witem) = @_;
	lastfm_forky($witem, $data);
}

sub lastfm {
		my ($content, $url, $alt, $artist, $track, $album, $time);
		my $user_shifted = shift;
		my $user = $user_shifted || Irssi::settings_get_str("lastfm_user");
		my $is_tabbed = shift;
		my $strftime = Irssi::settings_get_str("lastfm_strftime");
		my $nowplaying = shift || ((Irssi::settings_get_str("lastfm_output_tab_complete") ne "" && $is_tabbed) ? Irssi::settings_get_str("lastfm_output_tab_complete") : Irssi::settings_get_str("lastfm_output"));

		my $command_message = ($is_tabbed) ? '$np(username)' : '/np username';
		die("You must /set lastfm_user to a username on Last.fm or use $command_message") if $user eq '';

		my $url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=$user&api_key=$api_key&limit=1";
		print_raw "Checking for scrobbles at: $url" if DEBUG;
		$content = get($url);

		# TODO This doesn't work because LWP::Simple::get doesn't return any content unless it gets an 200
		die $1 if ($content =~ m!<lfm status="failed">.*<error .*?>([^<]+)!s);

		my $regex = qr!<$fields.*?(?:uts="(.*?)">.*?|>(.*?))</\1>!;
		my @data = grep(/$regex/, split('\n', $content));
		my ($tag, $value, %data); 
		foreach my $data (@data) {
			($tag, $value) = ($1, (defined($2) ? $2 : $3)) if ($data =~ /$regex/);
			$data{$tag} = $value;
		}
		print_raw "Using output pattern: $nowplaying" if DEBUG;
		print_raw Dumper %data if DEBUG;

		if (!defined $data{'artist'}) {
			die($errormsg_pre." yet".$errormsg_post);
		}

		if (defined $data{'date'}) {
			if ($data{'date'} < strftime('%s', gmtime()) - 60 * 30) {
				die($errormsg_pre." within the last 30 minutes".$errormsg_post);
			}
			$data{'date'} = strftime($strftime, localtime(scalar($data{'date'})));
		}
		else {
			undef $data{'date'};
		}
		$nowplaying =~ s/%$fields/$data{$1}/ge;
		$nowplaying =~ s/&amp;/&/g;
		$nowplaying =~ s/&gt;/>/g;
		$nowplaying =~ s/&lt;/</g;
		$nowplaying =~ s/&quot;/"/g;
		Encode::from_to($nowplaying, "utf-8", Irssi::settings_get_str("term_charset"));
		$nowplaying = "$user_shifted $nowplaying" if $user_shifted;
		return $nowplaying;
}

sub lastfm_forky {
	my $witem = shift;
	my $user = shift || 0;
	my @user = split(/ /, $user);
	$user = $user[0];
	if ($pid or $input_tag) {
		Irssi::active_win()->print("We're still waiting for Last.fm to return our data or to hit the timeout (this happends when Last.fm is down or very slow).");
		return;
	}

	my ($reader, $writer);
	pipe($reader, $writer);
	$pid = fork();
	if (!defined $pid) {
		close $reader;
		close $writer;
		return;
	}
	if ($pid > 0) {
		close $writer;
		Irssi::pidwait_add($pid);
		my @args = ($witem, $reader);
		$input_tag = Irssi::input_add(fileno($reader), INPUT_READ, \&input_read, \@args);
		return;
	}
	my $response;
	eval {
		$response = lastfm($user);
	};
	if ($@) {
		$response = $@;
	}
	print $writer $response;
	close $writer;
	POSIX::_exit(1);
}

sub input_read {
	my ($witem, $reader) = @{$_[0]};
	my @content = <$reader>;
	my $content = join('', @content);

	if ($content =~ /^(.+) at \(eval \d+\) line \d+/) {
		Irssi::active_win()->print($1);
	}
	else {
		if (defined $witem->{type} && $witem->{type} =~ /^QUERY|CHANNEL$/) {
			if (Irssi::settings_get_bool("lastfm_use_action")) {
				$witem->command("me $content");
			}
			else {
				$witem->command("say $content");
			}
		}
		else {
			print($content);
		}
	}

	Irssi::input_remove($input_tag);
	close $reader;
	$input_tag = $pid = undef;
}

Irssi::command_bind('np', 'cmd_lastfm', 'lastfm');

Irssi::signal_add_last 'complete word' => sub {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
  my $tab_fields = $fields;
  $tab_fields =~ s/\(/(nowplaying|np|/;
	my $is_tabbed = 1;
	if ($word =~ /%(lastfm|lfm)/) {
		my $user = Irssi::settings_get_str("lastfm_user");
		if (!defined $user) {
			Irssi::active_win()->print("You must /set lastfm_user to a username on Last.fm");
			return;
		}
		push @$complist, "http://last.fm/user/$user/";
	}
	elsif ($word =~ /(\%(?:$tab_fields))\(?(\w+)?\)?/) {
		my ($nowplaying, $user) = $1, $2;
    undef $nowplaying if ($nowplaying =~ /nowplaying|np/);
		eval {
			$nowplaying = lastfm($user, $is_tabbed, $nowplaying);
		};
		if ($@) {
			Irssi::active_win()->print($1) if ($@ =~ /^(.+) at \(eval \d+\) line \d+/);
		}
		push @$complist, "$nowplaying" if $nowplaying;
	}
};
