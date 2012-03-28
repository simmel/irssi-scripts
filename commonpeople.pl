# vim: set expandtab:
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
        authors     => "Simon 'simmel' Lundström",
        contact     => 'simmel@(freenode|quakenet|efnet) http://last.fm/user/darksoy',
        name        => "commonpeople",
        date        => "20120328",
        description => 'Show the common people/nicks of two channels',
        license     => "BSD",
        url         => "http://soy.se/code/",
);

use strict;
use warnings;
use Data::Dumper;
use Irssi;

sub cmd_common {
  my ($data, $server, $witem) = @_;

  my @channels;
  my ($channel1, $channel2) = split / /, $data;
  for my $i (split / /, $data) {
    my %channel;
    $channel{'channel'} = $i;
    push @channels, \%channel;
  }

  @channels = map {
    $$_{'network'} = $server->{'chatnet'};
    if ($$_{'channel'} =~ /:/) {
      my ($tmp_network, $tmp_channel) = split /:/, $$_{'channel'};
      if (Irssi::server_find_chatnet($tmp_network)) {
        $$_{'channel'} = $tmp_channel;
        $$_{'network'} = $tmp_network;
      }
    }
    my @nicks;
    my $channel = Irssi::server_find_chatnet($$_{'network'})->channel_find($$_{'channel'});
    foreach my $nick ($channel->nicks()) {
      push @nicks, $nick->{'nick'};
    }
    $$_{'nicks'} = \@nicks;
    $_;
  } @channels;

  my %seen;
  my @common = grep { $seen{$_}++ == 1 } @{$channels[0]->{'nicks'}}, @{$channels[1]->{'nicks'}};
  Irssi::print("Common users between ".$channels[0]->{'channel'}." (".$channels[0]->{'network'}.") and ".$channels[1]->{'channel'}." (".$channels[1]->{'network'}."): ".join(', ', @common));
  Irssi::print("Number of common users: ".($#common+1));
}

Irssi::command_bind('common', 'cmd_common');
