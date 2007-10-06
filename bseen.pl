use strict;
use Data::Dumper;
use File::Copy;
use POSIX;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
    authors => "Simon 'simmel' Lundström",
    contact => "simmel@(undernet|quakenet|freenode|efnet)",
    name    => "bseen",
    description => "a port of bseen.tcl to irssi implementing most of the features",
    license => "BSD, but please send bugs/improvements/suggestions/candy/soda to me",
    url     => "http://soy.se/simon/dev/perl/",
    modules => "File::Copy",
    changed => "2005-04-05"
);

#bs(limit) is the database record limit.  
Irssi::settings_add_int("bseen", "bs_limit", 4000);

#bs(backupinterval) interval between backups in minutes
Irssi::settings_add_time("bseen", "bs_backupinterval", 15);

#bs(backupverbose) show messages, when i backup etc.
Irssi::settings_add_bool("bseen", "bs_backupverbose", 1);

#bs(nicksize) is the maximum nickname length (9 on Undernet)
Irssi::settings_add_int("bseen", "bs_nicksize", 12);

#TODO?
#bs(searchallnetworks) searches all networks that the bot is connected to.
Irssi::settings_add_bool("bseen", "bs_searchallnetworks", 0);

#bs(no_pub) is a list of channels you *don't* want the bot to post public 
#  replies to (public queries ignored).  Enter in lower case, eg: network,#lamer
Irssi::settings_add_str("bseen", "bs_no_pub", "");

#bs(quiet_chan) is a list of channels you want replies to requests sent  
#  to the person who made the query via notice. (The bot replies to  
#  public queries via notice.)  Enter in lower case, eg: network,#lamer
Irssi::settings_add_str("bseen", "bs_quiet_chan", "");

#bs(no_log) is a list of channels you *don't* want the bot to log
#  data on.  Enter chans in lower case. E.g: network,#channel
#  To ignore a whole network use: network,#
#  E.g "quakenet,#lamers efnet,#lamers freenode,# undernet,#lamers"
Irssi::settings_add_str("bseen", "bs_no_log", "");

#bs(log_only) is a list of channels you *only* want the bot to log
#  data on.  This is the opposite of bs(no_log).  Set it to "" if you 
#  want to log new channels the bot joins.  Enter chans in lower case.
# E.g: network,#channel
Irssi::settings_add_str("bseen", "bs_log_only", "");

#bs(cmdchar) is what command character should be used for making public 
#  queries.  The default is "!".  Setting it to "" is a valid option.
Irssi::settings_add_str("bseen", "bs_cmdchar", "");

#bs(hidereplies) is used to disable so that you see what you reply when
#  answering a seen request.
Irssi::settings_add_bool("bseen", "bs_hidereplies", 0);

#bs(flood) is used for flood protection, in the form x:y.  Any queries
# from a single user  beyond x in y seconds is considered a flood and ignored.
Irssi::settings_add_str("bseen", "bs_flood", "4:15");

#bs(flood_levels) are the levels (see /help levels) that are ignored from a user
# that floods.
Irssi::settings_add_str("bseen", "bs_flood_levels", "PUBLIC MSGS");

#bs(ignore) is used as a switch for ignoring flooders (1=on)
Irssi::settings_add_bool("bseen", "bs_flood_ignore", 1);

#bs(ignore_time) is used to define the amount of time a flooder is 
#  ignored (minutes).  This is meaningless if bs(ignore) is 0.
Irssi::settings_add_time("bseen", "bs_flood_ignore_time", 2);

# if someone misses this function, i will implement it. but i havent used it in
# all years i've been using bseen - simmel
#bs(smartsearch) is a master enable/disable for SmartSearch.  SmartSearch ensures that
#  the most accurate and current results are returned for nick queries. (1=on)
#Irssi::settings_add_bool("bseen", "bs_smartsearch", 1);

# not implemented.
#bs(logqueries) is used to log DCC/MSG/PUB queries
#Irssi::settings_add_bool("bseen", "bs_logqueries", 1);

#bs(path) is used to indicate what path to save the database and backup to.  
#  Setting to "" will cause the script to be saved in the same path as the eggdrop executable
#  If you set it, use the full path, and make sure you terminate w/ a "/".  
#  eg:  set bs(path) "/usr/home/mydir/blah/", defaults in your homedir.
Irssi::settings_add_str("bseen", "bs_path", "");


# variables
my $bs_list;
my $bs_idle;
my %bs;
$bs{'updater'} = 10403;
$bs{'version'} = "bseen1.4.3";
my %bs_flood_array;

bs_read();

# timers
# lägg till ignore timer
my $bs_backup_timeout = Irssi::settings_get_time("bs_backupinterval")*60*1000;
my $bs_backup_timer = Irssi::timeout_add($bs_backup_timeout, 'bs_save', undef);
($bs{'flood_num'}, $bs{'flood_time'}) = split(/:/,Irssi::settings_get_str("bs_flood"));
my $bs_flood_timer = Irssi::timeout_add($bs{'flood_time'}, 'bs_flood_clean', undef);
#my $bs_backup_timer = Irssi::timeout_add(Irssi::settings_get_time("bs_backupinterval")*60*1000, 'bs_save', undef);
Irssi::command_bind("heij", sub { print Dumper $bs_flood_array{"quakenet"}{"simmel"}; });
sub UNLOAD {
	# tabort timersarna
	bs_save();
	timeout_remove($bs_backup_timer);
}
# functions
sub bs_getpath
{
	# please, i told you so.
	die ("use a / at the end of path") if (Irssi::settings_get_str("bs_path") !=~ /^.*\/$/ && Irssi::settings_get_str("bs_path") ne "");
	if (Irssi::settings_get_str("bs_path") eq "")
	{
		return Irssi::get_irssi_dir."/";
	}
	else
	{
		my $path = Irssi::settings_get_str("bs_path");
	}
}
sub bs_getver
{
   my ($file) = @_;
   open (FS, "<$file");
	flock FS, 2;
   my $version = <FS>;
   flock FS, 8;
   close FS;
   $version =~ s/^#([\d]*)/$1/;
   return $version;
}
sub getnetwork
{
	my ($server) = @_;
	if ($server->{'chatnet'} ne "")
	{
		return $server->{'chatnet'};
	}
	else
	{
		return $server->{'tag'};
	}
}
sub bs_save
{
#	bs_read();
	# please, i told you so.
	my $path = bs_getpath();
	foreach my $server (Irssi::servers())
	{
		my $network = getnetwork($server);
		my $botnick = $server->{'wanted_nick'};
		# backup
		if (-e $path."bs_data.$network.$botnick")
		{
			my $old = $path."bs_data.$network.$botnick";
			my $new = $path."bs_data.$network.$botnick.bak";
			copy($old, $new);
		}
		open(FS, ">".$path."bs_data.$network.$botnick");
		flock FS, 2;
		print FS "#".$bs{'updater'}."\n";
      
#		for my $network ( keys %$bs_list )
#		{
		my $i = 1;
		for my $nick ( keys %{$bs_list->{$network}} )
		{
			print FS "$network $nick ".$bs_list->{$network}->{$nick}."\n";
			last FS if ($i == Irssi::settings_get_int("bs_limit"));
			$i++;
		}

#		}
		flock FS, 8;
		close FS;

		# backingup idle
		open(FS, ">".$path."bs_idle.$network.$botnick");
		flock FS, 2;

		for my $nick ( keys %{$bs_idle->{$network}} )
		{
			print FS "$network $nick ".$bs_idle->{$network}->{$nick}."\n";
		}

		flock FS, 8;
		close FS;

		Irssi::print "backed up bseen list for $network" if (Irssi::settings_get_bool("bs_backupverbose"));
	}
}

sub bs_read
{
	# please, i told you so.
	my $path = bs_getpath();
	foreach my $server (Irssi::servers())
	{
		my $file;
		my $network = getnetwork($server);
		my $botnick = $server->{'wanted_nick'};
		last if (Irssi::settings_get_str("bs_no_log") =~ /$network,#/i);
		if (-e $path."bs_data.$network.$botnick")
		{
			$file = $path."bs_data.$network.$botnick";
			die("i told you to update your bs_data file.") if (bs_getver("$file") > 10403);
		}
		else
		{
			print "can't find ".$path."bs_data.$network.$botnick";
			print "if you are loading the script for the first time, don't worry.";
			if (-e $path."bs_data.$network.$botnick.bak")
			{
				$file = $path."bs_data.$network.$botnick.bak";
			}
			else
			{
				$file = $path."bs_data.$network.$botnick";
			}
			die("i told you to update your bs_data file.") if (bs_getver("$file") > 10403);
			print "no backup avalible! if you should have one, worry now." if (!-e $path."bs_data.$network.$botnick.bak");
		}
		open(FS, "<$file");
		flock FS, 2;
		while (<FS>)
		{
			my ($network, $nick, $etc) = split(/ /, $_, 3);
		   $etc =~ s/\n//;			
			$bs_list->{$network}->{$nick} = $etc unless /^#[\d]*$/;
		}
		flock FS, 8;
		close FS;
		my $ref = $bs_list->{$network};
		my $records = scalar keys %$ref;
		Irssi::print "restored bseen list for $network, with #$records records." if (Irssi::settings_get_bool("bs_backupverbose"));

		# restoring idle
		if (-e $path."bs_idle.$network.$botnick")
		{
			$file = $path."bs_idle.$network.$botnick";
#			undef($bs_idle->{$network});
			open(FS, "<$file");
			flock FS, 2;
			while (<FS>)
			{
				my ($network, $nick, $etc) = split(/ /, $_, 3);
			   $etc =~ s/\n//;			
				$bs_idle->{$network}->{$nick} = $etc unless /^#[\d]*$/;
			}
			flock FS, 8;
			close FS;
		}
		
	}
}

# signals
Irssi::signal_add(
{
   # seen and logging
   'message private'       => \&event_private,
   'message public'        => \&event_public,
   # lastspoke
#   'redir idle_save'       => \&event_idle_save,
   # saving data
   'message join'          => \&event_join,
   'message part'          => \&event_part,
   'message quit'          => \&event_quit,
   'message kick'          => \&event_kick,
   'message nick'          => \&event_nick
}
);


# events

# seen, seennick, lastspoke

sub event_private
{
   #"message private", SERVER_REC, char *msg, char *nick, char *address
   my ($server, $etc, $nick, $uhost) = @_;
   my ($switch, $target) = split(/ /, $etc, 2);
	# protection from nickcompletion's trailing space
   my ($target) = split(/ /, $target, 2);
   my $network = getnetwork($server);

   $bs_idle->{$network}->{$nick} = time;

   # if i return 1 it won't show the msg?
   return 0 if (length($target) > Irssi::settings_get_int("bs_nicksize"));
	return 0 if (bs_flood($network, $nick, $uhost));
   $_ = $switch;
   my $cmdchar = Irssi::settings_get_str("bs_cmdchar");
   my $output;

   if ($_ eq "${cmdchar}seennick" || $_ eq "${cmdchar}seen")
   {
		return 0 if (bs_flood($network, $nick, $uhost, 1));
      $output = bs_seen($server, $network, $nick, $uhost, $target, $switch, $nick);
   }

   elsif ($_ eq "${cmdchar}lastspoke")
   {
		return 0 if (bs_flood($network, $nick, $uhost, 1));
      $output = bs_lastspoke($server, $network, $nick, $uhost, $target);
   }

   else
   {
      return 0;
   }

   my $command;
   $command = "^" if (Irssi::settings_get_bool("bs_hidereplies"));
   $command .= "msg $nick";
   $server->command("$command $output");
}

sub event_public
{
   #"message public", SERVER_REC, char *msg, char *nick, char *address, char *target
   my ($server, $etc, $nick, $uhost, $channel) = @_;
   my ($switch, $target) = split(/ /, $etc, 2);
	# protection from nickcompletion's trailing space
   my ($target) = split(/ /, $target, 2);
   my $network = getnetwork($server);
   $bs_idle->{$network}->{$nick} = time;
	return 0 if (bs_flood($network, $nick, $uhost));
   return 0 if (Irssi::settings_get_str("bs_no_pub") =~ /$network,$channel/i);
   return 0 if (length($target) > Irssi::settings_get_int("bs_nicksize"));

   $_ = $switch;
   my $cmdchar = Irssi::settings_get_str("bs_cmdchar");
   my $output;

   if ($_ eq "${cmdchar}seennick" || $_ eq "${cmdchar}seen")
   {
		return 0 if (bs_flood($network, $nick, $uhost, 1));
      $output = bs_seen($server, $network, $nick, $uhost, $target, $switch, $channel);
   }

   elsif ($_ eq "${cmdchar}lastspoke")
   {
   	if ($server->channel_find($channel)->nick_find($target))
		{
			return 0 if (bs_flood($network, $nick, $uhost, 1));
			$output = bs_lastspoke($server, $network, $nick, $uhost, $target);
		}
		else
		{
			return 0;
		}
   }

   else
   {
      return 0;
   }

   my $command;
   $command = "^" if (Irssi::settings_get_bool("bs_hidereplies"));
   if (Irssi::settings_get_str("bs_quiet_chan") =~ /$network,$channel/i)
   {
      $command .= "notice $nick";
   }
   else
   {
      $command .= "msg $channel $nick,";
   }
   $server->command("$command $output");
}


sub event_join
{
	my ($server, $channel, $nick, $mask) = @_;
	my $network = getnetwork($server);
	my $time = time;
	if ($server->netsplit_find($nick, $mask))
	{
		bs_add($network,$nick,"$mask $time rejn $channel");
	}
	else
	{
		bs_add($network,$nick,"$mask $time join $channel");
	}
}
sub event_part
{
	my ($server, $channel, $nick, $mask, $etc) = @_;
	my $network = getnetwork($server);
	my $time = time;
	delete($bs_idle->{$network}->{$nick});
	bs_add($network,$nick,"$mask $time part $channel $etc");
}
sub event_quit
{
	my ($server, $nick, $mask, $etc) = @_;
	my $network = getnetwork($server);
	my $time = time;
	my $channel = "#";
	delete($bs_idle->{$network}->{$nick});
	if ($server->netsplit_find($nick, $mask))
	{
		bs_add($network,$nick,"$mask $time splt $channel $etc");
	}
	else
	{
		bs_add($network,$nick,"$mask $time quit $channel $etc");
	}
}
sub event_kick
{
	my ($server, $channel, $nick, $kicker, $mask, $etc) = @_;
	my $network = getnetwork($server);
	my $time = time;
	bs_add($network,$nick,"$mask $time kick $channel $kicker $etc");
}
sub event_nick
{
	my ($server, $newnick, $oldnick, $mask) = @_;
	my $network = getnetwork($server);
	my $time = time;
	my $channel = "#";
	bs_add($network,$oldnick,"$mask $time nick $channel $newnick");
}
sub event_topic
{
	my ($server, $channel, $topic, $nick, $mask) = @_;
	my $network = getnetwork($server);
	my $time = time;
	bs_add($network,$nick,"$mask $time topic $channel $topic");
}

#lastspoke
sub bs_lastspoke
{
   my ($server, $network, $nick, $uhost, $target) = @_;
   return "go look in a mirror." if (lc($nick) eq lc($target));
   return "must you waste my time?" if (lc($server->{'wanted_nick'}) eq lc($target));
   
   if (exists($bs_idle->{$network}->{$target}))
   {
      my $ago = bs_when(time-$bs_idle->{$network}->{$target});
      return "$target last uttered a word $ago ago.";
   }
   else
   {
      my $ago = bs_when(time - $server->{'connect_time'});
      return "$target hasn't uttered a word since I connected $ago ago.";
   }
}

#flood
sub bs_flood_clean
{
	foreach my $network (keys %bs_flood_array)
	{
		foreach my $nick (keys %{$bs_flood_array{$network}})
		{
			if (time-$bs_flood_array{$network}{$nick}{'time'} > $bs{'flood_time'})
			{
				delete($bs_flood_array{$network}{$nick});
			}
		}
	}
}
sub bs_flood_init
{
   die ("check your bs_flood settings syntax") if (Irssi::settings_get_str("bs_flood") !~ /^[\d]+:[\d]+$/);
   ($bs{'flood_num'}, $bs{'flood_time'}) = split(/:/,Irssi::settings_get_str("bs_flood"));
}

bs_flood_init;

sub bs_flood
{
	my ($network, $nick, $uhost, $add) = @_;
	return 0 if ($bs{'flood_num'} == 0 || !Irssi::settings_get_bool("bs_flood_ignore"));
	if ($add)
	{
		$bs_flood_array{$network}{$nick}{'time'} = time unless exists $bs_flood_array{$network}{$nick}{'time'};
		$bs_flood_array{$network}{$nick}{'count'}++;
	}
	my $time = time;
	if ($bs_flood_array{$network}{$nick}{'count'} >= $bs{'flood_num'} && $time-$bs_flood_array{$network}{$nick}{'time'} >= $bs{'flood_time'})
	{
		print "flood detected from: $nick on $network";
		my $ignoretime = Irssi::settings_get_time("bs_flood_ignore_time")/1000*60;
		my $levels = Irssi::settings_get_str("bs_flood_levels");
		$uhost =~ /^.*@(.*)$/;
		$uhost = $1;
		Irssi::command("ignore -network $network -time $ignoretime *!*\@$uhost $levels");
		delete($bs_flood_array{$network}{$nick});
		return 1;
	}
	else
	{
		return 0;
	}
}

#misc

sub bs_add
{
   my ($network, $nick, $etc) = @_;
   my ($uhost, $crap) = split(/ /, $etc, 2);
   my ($mask, $time, $event, $channel, $reason) = split(/ /, $etc);
	return 0 if (
	Irssi::settings_get_str("bs_no_log") =~ /$network,$channel/i
	||
	(Irssi::settings_get_str("bs_log_only") ne ""
		&&
	Irssi::settings_get_str("bs_log_only") !~ /$network,$channel/i)
	);

	$bs_list->{$network}->{$nick} = $etc;
}

sub bs_when
{
   my ($time) = @_;
   my ($years, $days, $hours, $mins) = 0;
   my $output;
   return "only $time seconds" if ($time < 60);
   if ($time >= 31536000)
   {
      $years = int($time/31536000);
      $time = $time-(31536000*$years);
   }
   if ($time >= 86400)
   {
      $days = int($time/86400);
      $time = $time-(86400*$days);
   }
   if ($time >= 3600)
   {
      $hours = int($time/3600);
      $time = $time-(3600*$hours);
   }
   if ($time >= 60)
   {
      $mins = int($time/60);
      $time = $time-(60*$mins);
   }
   $output .= "1 year, " if ($years == 1);
   $output .= $years." years, " if ($years > 1);
   $output .= "1 day, " if ($days == 1);
   $output .= $days." days, " if ($days > 1);
   $output .= "1 hour, " if ($hours == 1);
   $output .= $hours." hours, " if ($hours > 1);
   $output .= "1 minute, " if ($mins == 1);
   $output .= $mins." minutes, " if ($mins > 1);
   $output .= "1 second, " if ($time == 1);
   $output .= "$time seconds, " if ($time > 1);
   $output =~ s/^(.*), $/$1/;
   return $output;
}

sub bs_sort
{
   my ($network,@nicks) = @_;
   my $ref = $bs_list->{$network};
   my $bs_sorted;
   foreach my $nick (@nicks)
   {
      my ($uhost, $time, $etc) = split(/ /,$ref->{$nick}, 3);
      $bs_sorted->{$nick} = $time;
   }
   reverse(map { $_->[0] }
   sort { $a->[1] <=> $b->[1] }
   map { [$_, $bs_sorted->{$_}] }
   keys %{$bs_sorted});
}

sub bs_online
{
	my ($server, $nick, $channel) = @_;
	my $networkwide = 0;
	if ($networkwide)
	{
		foreach my $channel (Irssi::channels())
		{
			if (my $nicks = $channel->nick_find($nick))
			{
				#return channelnames?
				return 1;
			}
		}
#		return 0;
	}
	elsif ($channel)
	{
		if ($server->channel_find("$channel")->nick_find($nick))
		{
			return 1;
		}
	}
	else
	{
		foreach my $channel ($server->channels())
		{
			if (my $nicks = $channel->nick_find($nick))
			{
				#return channelnames?
				return 1;
			}
		}
	}
	return 0;
}

sub bs_seen
{
   my ($server, $network, $nick, $uhost, $target, $switch, $channel) = @_;
   my $regex;
   my $cmdchar = Irssi::settings_get_str("bs_cmdchar");

	if ($server->channel_find($channel))
	{
		return "$target is right here!" if ($server->channel_find($channel)->nick_find($target));
	}
   # TODO add so you can search by hosts and channels aka smartsearch
   #my @split = split(/ /, $etc, 2);
   #my $_ = scalar(@split);

	if ($target =~ /[\*|\?]/)
	{
		$regex = 1;
	}
	else
	{
		$regex = 0;
	}
   if ("${cmdchar}seennick")
   {
      $target =~ s/[\*|\?]//g;
   }
   elsif ("${cmdchar}seen")
   {
      $target =~ s/\*/\.\*/g;
      $target =~ s/\?/\./g;
   }
   my $ref = $bs_list->{$network};
   my @matches = grep(/$target/i, keys %$ref);
   @matches = bs_sort($network,@matches);
   my $matches = @matches;
   my $result = join(", ", @matches);
   my $output;
   return "go look in a mirror." if (lc($nick) eq lc($target));
   return "I'm right here. Quit wasting my time!" if (lc($server->{'wanted_nick'}) eq lc($target) || lc($server->{'nick'}) eq lc($target));
   if ($matches == 0 && $regex && $switch eq "seen")
   {
      return "No matches were found.";
   }
   elsif ($matches == 0 && !$regex)
   {
      return "I don't remember seeing $target.";
   }
   elsif ($matches == 1)
   {
      return bs_output($server, $network, $nick, $matches[0]);
   }
	# shouldn't $matches == 2..5 work?
   elsif ($matches => 2 && $matches <= 5)
   {
      $output = "I found $matches matches to your query (sorted): ${result}. ";
   }
   elsif ($matches > 99)
   {
      return "I found $matches matches to your query; please refine it to see any output.";
   }
   else
   {
      $output = "I found $matches matches to your query. Here are the 5 most recent (sorted): ";
      for (my $i=0;$i<5;$i++)
      {
			$output .= ", " if ($i == 1..3);
         $output .= $matches[$i];
			$output .= ". " if ($i == 4);
      }
   }
   return "$output".bs_output($server, $network, $nick, $matches[0]);
}

sub bs_output
{
   my ($server, $network, $nick, $target) = @_;
   my $output;
   return 0 if ($target eq "");
   my ($uhost, $time, $action, $channel, $etc) = split(/ /, $bs_list->{$network}->{$target}, 5);
   $_ = $action;
	my $channels;
	for my $chanref ($server->channels)
	{
		for my $chan ($chanref->{'name'})
		{
			$channels .= "$chan ";
		}
	}
	if ($channels =~ /$channel/i)
	{
		print Dumper $server;
		print Dumper $channel;
		my $mode = $server->channel_find($channel)->{'mode'};
		$channel = "-secret-" if ($mode =~ /s/);
	}
   my $ago = bs_when(time-$time);
   if ($action eq "part")
   {
      if ($etc eq "")
      {
         $etc = ".";
      }
      else
      {
         $etc = " stating \"$etc\".";
      }
      $output = "$target ($uhost) was last seen parting $channel $ago ago$etc";
   }
   elsif ($action eq "quit")
   {
      $output = "$target ($uhost) was last seen quitting $ago ago stating $etc";
   }
   elsif ($action eq "kick")
   {
      my ($kicker, $reason) = split(/ /, $etc, 2);
      $output = "$target ($uhost) was last seen being kicked from $channel by $kicker $ago ago with the reason ($reason)";
   }
	# TODO implement a setting which allows for looking up newnick.
	# koll upp:
	#		* om den finns på nån kanal vi är på:
	#			* visa, om den inte är +s.
	#		* om inte:
	#			* säg det
	#			* om det är inställt så gör en lookup. (antal djup)
   elsif ($action eq "nick")
   {
      $output = "$target ($uhost) was last seen changing nicks to $etc $ago ago.";
#		if (bs_online($server, $target))
# 		{
# 			
# 		}
		if ($server->channel_find($channel))
		{
	      if ($server->channel_find($channel)->nick_find($etc))
	      {
				$output .= " $etc is still there.";
	      }
			else
	      {
				$output .= " I don't see $etc now, though.";
	         # we could do a lookup here, but it could be a possible DoS..
	      }
		}
      else
      {
         $output .= " I don't see $etc now, though.";
         # we could do a lookup here, but it could be a possible DoS..
      }
   }
   elsif ($action eq "splt")
   {
      $output = "$target ($uhost) was last seen parting due to a split $ago ago.";
   }
   elsif ($action eq "rejn")
   {
      $output = "$target ($uhost) was last seen rejoining $channel from a split $ago ago.";
		if (bs_online($server, $target, $channel))
		{
			$output .= " $target is still on $channel.";
		}
      else
		{
        	$output .= " I don't see $target on $channel now, though.";
		}
   }
   elsif ($action eq "join")
   {
      $output = "$target ($uhost) was last seen joining $channel $ago ago.";
		if (bs_online($server, $target, $channel))
		{
			$output .= " $target is still on $channel.";
		}
      else
		{
        	$output .= " I don't see $target on $channel now, though.";
		}
   }
   else
   {
      $output = "error";
   }
   return $output;
}

# sub bs_output
# {
#    my ($server, $network, $nick, $target) = @_;
#    my $output;
#    return 0 if ($target eq "");
#    my ($uhost, $time, $action, $channel, $etc) = split(/ /, $bs_list->{$network}->{$target}, 5);
#    $_ = $action;
# 	my $channels;
# 	for my $chanref ($server->channels)
# 	{
# 		for my $chan ($chanref->{'name'})
# 		{
# 			$channels .= "$chan ";
# 		}
# 	}
# 	if ($channels =~ /$channel/i)
# 	{
# 		my $mode = $server->channel_find("$channel")->{'mode'};
# 		$channel = "-secret-" if ($mode =~ /s/);
# 	}
#    my $ago = bs_when(time-$time);
#    if ("part")
#    {
#       if ($etc eq "")
#       {
#          $etc = ".";
#       }
#       else
#       {
#          $etc = " stating \"$etc\".";
#       }
#       $output = "$target ($uhost) was last seen parting $channel $ago ago$etc";
#    }
#    elsif ("quit")
#    {
#       $output = "$target ($uhost) was last seen quitting $ago ago stating $etc";
#    }
#    elsif ("kick")
#    {
#       my ($kicker, $reason) = split(/ /, $etc, 2);
#       $output = "$target ($uhost) was last seen being kicked from $channel by $kicker $ago ago with the reason ($reason)";
#    }
#    elsif ("rnck")
#    {
#       $output = "$target ($uhost) was last seen changing nicks from $etc on $channel $ago ago.";
# 		if ($server->channel_find($channel))
# 		{
# 	      if ($server->channel_find($channel)->nick_find($etc))
# 	      {
# 				$output .= " $etc is still there.";
# 	      }
# 			else
# 	      {
# 				$output .= " I don't see $etc now, though.";
# 	         # we could do a lookup here, but it could be a possible DoS..
# 	      }
# 		}
#       else
#       {
#          $output .= " I don't see $etc now, though.";
#          # we could do a lookup here, but it could be a possible DoS..
#       }
#    }
#    elsif ("nick")
#    {
#       $output = "$target ($uhost) was last seen changing nicks to $etc $ago ago.";
#    }
#    elsif ("splt")
#    {
#       $output = "$target ($uhost) was last seen parting due to a split $ago ago.";
#    }
#    elsif ("rejn")
#    {
#       $output = "$target ($uhost) was last seen rejoining $channel from a split $ago ago.";
# 		if ($server->channel_find($channel))
# 		{
# 			if ($server->channel_find($channel)->nick_find($target))
# 			{
# 				$output .= " $target is still on $channel.";
# 			}
# 	      else
# 			{
#          	$output .= " I don't see $target on $channel now, though.";
# 			}
# 		}
#       else
#       {
#          $output .= " I don't see $target on $channel now, though.";
#       }
#    }
#    elsif ("join")
#    {
#       $output = "$target ($uhost) was last seen joining $channel $ago ago.";
# 		if ($server->channel_find($channel))
# 		{
# 			if ($server->channel_find($channel)->nick_find($target))
# 			{
# 				$output .= " $target is still on $channel.";
# 			}
# 		}
#       else
#       {
#          $output .= " I don't see $target on $channel now, though.";
#       }
#    }
#    else
#    {
#       $output = "error";
#    }
#    return $output;
# }

