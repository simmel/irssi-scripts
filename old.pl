use Irssi qw(signal_add signal_continue signal_stop signal_emit command_bind active_win settings_add_str settings_get_str settings_add_bool settings_get_bool);
use vars qw($VERSION %IRSSI);
$VERSION = "1.2";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => 'simmel@(freenode|quakenet|efnet)',
        name        => "old",
        date        => "20080721",
        description => 'Appends an configurable character (asterisk by default) to URLs you have seen before and gives you the possibility to check before posting old URLs via /old',
        license     => "BSD",
        url         => "http://soy.se/code/",
);
# USAGE
# /set old_marker <character>
# /set old_self <ON|OFF> # if the URLs you paste yourself should be checked
# /old <URL>

# CHANGELOG#{{{
# 1.2 -- Mon 21 Jul 2008 10:00:53 CEST
# * There was an issue and potentionally an security problem with my grep-line.

# 1.1 -- Sun 20 Jul 2008 13:09:22 CEST
# * Added the config option "old_self" to be able turn of old check for your own URLs.

# 1.0 -- Fri 18 Jul 2008 22:13:22 CEST
# * Initial version#}}}

my $url_regex = qr!(https?://\S+)!;
die "Can't find grep in your \$PATH" unless (`which grep`);

settings_add_str("old", "old_marker", "*");
settings_add_bool("old", "old_self", 1);

sub cmd_old {
	my ($url) = @_;
	$url =~ s#$url_regex#old($1)#ge;
	active_win()->print($url);
}
sub old {
	my ($url) = @_;
	my $url_file = Irssi::get_irssi_dir."/old_urls.log";
	if (`grep -F '$url' '$url_file' &>/dev/null`) {
		$url .= settings_get_str("old_marker");
	}
	else {
		open URLS, ">> $url_file";
		print URLS "$url\n";
		close URLS;
	}
	$url;
}
sub message_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	$msg =~ s#$url_regex#old($1)#ge;
	signal_continue($server, $msg, $nick, $address, $target);
}
sub message_private {
	my ($server, $msg, $nick, $address) = @_;
	$msg =~ s#$url_regex#old($1)#ge;
	signal_continue($server, $msg, $nick, $address);
}
sub message_quit {
	my ($server, $nick, $address, $reason) = @_;
	$reason =~ s#$url_regex#old($1)#ge;
	signal_continue($server, $nick, $address, $reason);
}
sub message_kick {
	my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
	$reason =~ s#$url_regex#old($1)#ge;
	signal_continue($server, $channel, $nick, $kicker, $address, $reason);
}
sub message_topic {
	my ($server, $channel, $topic, $nick, $address) = @_;
	$topic =~ s#$url_regex#old($1)#ge;
	signal_continue($server, $channel, $topic, $nick, $address);
}
sub message_own_public {
	my ($server, $msg, $target) = @_;
	if (settings_get_bool("old_self")) {
		$msg =~ s#$url_regex#old($1)#ge;
		signal_continue($server, $msg, $target);
	}
}
sub message_own_private {
	my ($server, $msg, $target, $orig_target) = @_;
	if (settings_get_bool("old_self")) {
		$msg =~ s#$url_regex#old($1)#ge;
		signal_continue($server, $msg, $target, $orig_target);
	}
}

signal_add('message own_public', 'message_own_public');
signal_add('message own_private', 'message_own_private');
signal_add('message public', 'message_public');
signal_add('message private', 'message_private');
signal_add('message quit', 'message_quit');
signal_add('message kick', 'message_kick');
signal_add('message topic', 'message_topic');

command_bind('old', 'cmd_old');
