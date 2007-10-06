sub DEBUG () { 0 }
use strict;
no strict 'refs';
use URI::Escape;
use LWP::Simple;
use Irssi;
use DateTime;
use Encode;
use HTML::Entities;
use POSIX qw(strftime);
use Socket;
if (DEBUG)
{
	use Data::Dumper;
	use warnings;
}

use vars qw($VERSION %IRSSI);
our ($pid, $input_tag) = undef;

$VERSION = "2.2";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => 'simmel@(undernet|quakenet|freenode)',
        name        => "lastfm",
        date        => "20070818",
        description => 'Show with /np or $np<TAB> what song "lastfm_user" last submitted to Last.fm via /me, if "lastfm_use_action" is set, or /say (default) with an configurable message, via "lastfm_sprintf" with option to display a when it was submitted with "lastfm_strftime".',
        license     => "BSDw/e, please send bug-reports, suggestions, improvements.",
        url         => "http://soy.se/code/",
    );
# README: Read the description above and /set those settings (the ones quoted with double-quotes). Scroll down to Settings for a more information on how to configure.

# TODO
# * Apparently åäö and maybe UTF-8 doesn't work well with sprintf, investigate and fix if possible.

# Changelog
# 2.2 -- Sat Aug 18 02:20:44 CEST 2007
# * Now you can use $np(darksoy) to see what I play (or someone else for that matter ; ).

# 2.1 -- Tue Jul 17 12:50:18 CEST 2007
# * Now you can use $np or $nowplaying as a tab-completion too, but a warning here, this is a blocking action so irssi won't respond or be usable until it is finnished or the timeout is hit.
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

# The strftime(3) syntax used when displaying at what time a song was submitted.
Irssi::settings_add_str("lastfm", "lastfm_strftime", 'submitted at: %R %Z');

# If we should use /me instead of /say
Irssi::settings_add_bool("lastfm", "lastfm_use_action", 0);

sub cmd_lastfm
{
	my ($data, $server, $witem) = @_;
	print Dumper "cmd_lastfm", $witem->{'type'};
	lastfm($witem);
}

# lastfm($witem, $users) som bearbetar datan
# lastfm_display som agerar vad den ska göra med datan.

sub lastfm
{
	my $witem = shift;
	my $user = shift || Irssi::settings_get_str("lastfm_user");
	print Dumper "lastfm", $witem->{type};
	if ($pid or $input_tag)
	{
		print Dumper $pid, $input_tag;
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
		$input_tag = Irssi::input_add(fileno($reader), INPUT_READ, \&input_read, ('fest', $witem, $reader));
	}
	else
	{
		close($reader);
		my $sprintf = Irssi::settings_get_str("lastfm_sprintf");
		my $strftime = Irssi::settings_get_str("lastfm_strftime");

		if ($user eq "")
		{
			Irssi::active_win()->print("You must /set lastfm_user to an username on Last.fm");
			return;
		}

		my $content = get("http://ws.audioscrobbler.com/1.0/user/$user/recenttracks.xml");
		if (!defined $content)
		{
			Irssi::active_win()->print("Last.fm is probably down or maybe you have set lastfm_user (currently set to: $user) to an non-existant user.");
			return;
		}
		$content =~ m!<artist [^>]+>\s*?(.+?)\s*?</artist>\s+<name>\s*?(.+?)\s*?</name>.+?<album .+?>(.*?)(?:</album>)?\n.+?<date uts="(\d+)"!s;
#	print $4, " ", DateTime->now(time_zone => 'UTC')->epoch() - 30 * 60;
		if ($content eq "" || $4 < DateTime->now(time_zone => 'UTC')->epoch() - 60 * 30)
		{
			Irssi::active_win()->print("You haven't submitted a song to Last.fm within the last 30 minutes. (Maybe Last.fm submission service is down?)");
			return;
		}
		$strftime = strftime($strftime, localtime(scalar($4)));
		$content = sprintf($sprintf, $1, $2, $3, $strftime);
		Encode::from_to($content, 'utf-8', 'latin1');
		decode_entities($content);
		print $writer $content;
		close($writer);
		POSIX::_exit(1);
	}

}

sub input_read {
	print Dumper @_;
	my $witem = shift;
	my $reader = shift;
	Irssi::input_remove($input_tag);
	close($reader);
	$input_tag = $pid = undef;
	return;
#	my ($witem, $reader) = @_;
	my @content = <$reader>;
	my $content = join('', @content);
#	while (<$reader>) {
#		chomp;
#		print $_;
#	}
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
		$witem->print($content);
	}
	Irssi::input_remove($input_tag);
	close($reader);
	$input_tag = $pid = undef;
}

Irssi::command_bind('np', 'cmd_lastfm');

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
	elsif ($word =~ /\$(?:nowplaying|np)\(?(\w+)?\)?/)
	{
		my $nowplaying = lastfm($1);
		push @$complist, "$nowplaying" if $nowplaying;
	}
}
