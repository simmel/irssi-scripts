use strict;
use Irssi qw(
	command_bind
	settings_get_str settings_add_str
);
use vars qw($VERSION %IRSSI);
use Data::Dumper;
$VERSION = '1.5';
%IRSSI = (
    authors => "Simon 'simmel' Lundström",
    contact => "simmel@(undernet|quakenet|freenode|efnet)",
    name        => 'dice',
    description => 'Make life easier and random, let chance descide for you!',
    license => "BSDw/e, but please send bugs/improvements/suggestions/nuts/soda to me",
    url     => "http://soy.se/code/",
    changed => "2007-05-12"
);

#  "message public", SERVER_REC, char *msg, char *nick, char *address, char *target
# TODO
# * Make an language hash of words to "translate".

sub dice {
    # $data = "nick/#channel :text"
	my ($server, $msg, $nick, $address, $target) = @_;

	if ($msg =~ /^!dice (.*)$/)
	{
		my $text = $1;
		if ($text =~ / ; | ;|; /)
		{
			$server->command("MSG $target $nick, SLUTA HA MELLANSLAG RUNT/VID SEMIKOLONEN IDIOT!");
			return;
		}
		elsif ($text =~ / : | :|: /)
		{
			$server->command("MSG $target $nick, SEMIKOLON FUCKERS DO U HAVE IT?");
			return;
		}
		my @choose = split(/;/, $text);
		my $r_index = int(rand(@choose));
		my $r_line = $choose[$r_index];
		if (defined $target)
		{
			$server->command("MSG $target $nick, the dice commands: $r_line");
		}
		else
		{
			$server->command("MSG $nick $server->{'nick'}, the dice commands: $r_line");
		}
	}
  }

sub superdice {
	# $data = "nick/#channel :text"
	my ($server, $msg, $nick, $address, $target) = @_;

	if ($msg =~ /^\?dice (.*)\? (.*)$/)
	{
		my $fraga = $1;
		my $alternativ = $2;
		if ($fraga =~ /^[^\s]* (.*)/)
		{
			$fraga = $1;
		}
		my @choose = split(/;/, $alternativ);
		my $r_index = int(rand(@choose));
		my $r_line = $choose[$r_index];
		$server->command("MSG $target $nick, $r_line $fraga");
	}
  }

sub turbodice {
# $data = "nick/#channel :text"
    my ($server, $msg, $nick, $address, $target) = @_;

	if ($msg =~ /^\?dice (.*)\? (.*)$/)
	{
		my $fraga = $1;
		my $alternativ = $2;
		my @choose = split(/;/, $alternativ);
		my $r_index = int(rand(@choose));
		my $r_line = $choose[$r_index];
		my $hej = "hur mycket|hur många|varifrån|vem|vad|hur|var|varför|vilken|vilket|vilka|när|skall|ska|bör|är|how much|how many|where|who|what|how|why|which|when";
		$fraga =~ s/$hej/$r_line/i;
		$fraga =~ s/jag/du/gi;
		$fraga =~ s/dig/mig/gi;
		if (defined $target)
		{
			$server->command("MSG $target $nick, $fraga");
		}
		else
		{
			$server->command("MSG $nick $server->{'nick'}, $fraga");
		}
	}
}
Irssi::signal_add("message public", "dice");
Irssi::signal_add("message own_public", "dice");
#Irssi::signal_add("message public", "superdice");
Irssi::signal_add_last("message public", "turbodice");
Irssi::signal_add_last("message own_public", "turbodice");
