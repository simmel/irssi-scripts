use strict;
use Irssi;
use Irssi::Irc;
use LWP::UserAgent;
use Data::Dumper;
use XML::Simple 'XMLin';
use utf8;
use vars qw($VERSION %IRSSI);

$VERSION = '1.2';
%IRSSI = (
  authors     => "Simon 'simmel' Lundström",
  contact     => 'simmel@(freenode|quakenet|efnet)',
  name        => 'spotify',
  description => 'Displays the actual info of Spotify URLs',
  license     => 'ISC',
  url         => 'http://soy.se/code/spotify.pl',
);

sub print_in_active {
  my ($window, $message) = @_;
  if ($window) {
    $window->print("[spotify] $message", MSGLEVEL_CRAP);
  }
  else {
    Irssi::active_win()->print("[spotify] $message");
  }
}

sub spotifyuri_handler {
  my ($window, $text) = @_;
  if ($text =~ /(?:http:\/\/open.spotify.com\/|spotify:)(album|artist|track)[:\/]([a-zA-Z0-9]+)\/?/) {
    my $kind = $1;
    my $id = $2;
    my $url = "http://ws.spotify.com/lookup/1/?uri=spotify:$kind:$id";
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5);
    $ua->agent(%IRSSI->{'name'}.".pl/$VERSION ".$ua->agent());
    my $res = $ua->get($url);
    if ($res->is_success()) {
      my ($xml, $info) = (XMLin($res->content()), undef);

      if ($xml->{'artist'}->{'name'}) {
        $info .= $xml->{'artist'}->{'name'};
      }
      else {
        for (keys %{$xml->{'artist'}}) {
          $info .= $_.", ";
        }

        # Trim off the last ", "
        $info =~ s/, $//;
      }

      # Let's use an n-dash if we're UTF-8 enabled
      $info .= (Irssi::settings_get_str("term_charset") =~ /utf-8/i) ? "\x{2013}" : "-";

      if ($xml->{'name'}) {
        $info .= $xml->{'name'};
      }

      if ($xml->{'album'}->{'name'}) {
        $info .= " (" . $xml->{'album'}->{'name'} . ")";
      }

      print_in_active($window, $info);
    }

    elsif ($res->code =~ /40[40]/) {
      print_in_active($window, "spotify:$kind:$id is not available on Spotify");
    }

    else {
      print "lol whut? HTTP ".$res->code;
      print Dumper \$res;
      print Dumper \$ua;
    }
  }
}

Irssi::signal_add_last('message public', sub {
    spotifyuri_handler($_[0]->window_item_find($_[4]), $_[1]);
  });
Irssi::signal_add_last('message private', sub {
    spotifyuri_handler($_[0]->window_item_find($_[2]), $_[1]);
  });
Irssi::signal_add_last('ctcp action', sub {
    spotifyuri_handler($_[0]->window_item_find($_[4]), $_[1]);
  });
Irssi::signal_add_last("message irc notice", sub {
    spotifyuri_handler($_[0]->window_item_find($_[2]), $_[1]);
  });
