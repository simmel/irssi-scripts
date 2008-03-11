sub DEBUG { 0 }
use strict;
use warnings;
if (DEBUG) { eval "use Data::Dumper"; }
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "2.1";
%IRSSI = (
    authors => "Simon 'simmel' Lundström",
    contact => "simmel@(undernet|quakenet|freenode|efnet)",
    name    => "wikipedia",
    description => "An script which answers to !wp<wikipedia language> <wikipedia article> [@[ ]<nickname to tell it to>]",
    license => "BSDw/e, but please send bugs/improvements/suggestions/nuts/soda to me",
    url     => "http://soy.se/simon/dev/perl/",
    changed => "2008-03-11"
);

# HISTORY
# 2.1
# * Added the posibility to direct the URL to the channel. Maybe this should be the default?
# <2.0
# * Lost due to nonexistant backups so I rewrote it.

# TODO
# ?

# http://en.wikipedia.org/wiki/List_of_Wikipedias
our @languages = qw(en de fr pl ja nl it pt sv es ru zh fi no eo sk da cs he ca hu id ro sr tr sl lt bg uk ko et hr te ar gl nn fa th el ms eu io nap bn is ka simple vi bs lb br sq mk wa la sh ht ku scn ru-sib lv mr ast af su oc ksh be cy tl uz ta co an cv kn gd ga tt az vec tg jv fy ur ia nds hi lmo als hy yi li sw zh-min-nan ilo fo nrm pms frp war sco os pam fur ceb nds-nl ml zh-yue kw new ug lij pdc map-bms nov se lad csb vo mt am ang ps vls sa bat-smg fiu-vro mi diq qu mo ty mn ks jbo nah tk tpi ie ky ne rm arc tokipona ln na kk roa-rup udm wo to gu mg bo tet dv rmy zh-classical sc av gv kg wuu pag ba chr si bm sd got eml km hsb sm zu bar iu my tlh nv yo cu kl ab haw lo pa so st cdo pap gn ay rw bpy glk xh fj zea bi kv xal pi tn za kr ce roa-tara cbk-zam ha tum ff tw ig cr ii ik rn lg aa sg om ny sn ho ak pih bug as ts ee ki kj chy hz mh bh ti ng ve or ss cho mus bxr dz ch mzn lbe);

Irssi::signal_add_last("message public", "msg_pub_event");

sub msg_pub_event
{
	my ($server, $msg, $nick, $address, $target) = @_;
	if ($msg =~ /^!wp[^ ]* (.+)/)
	{
		my ($reply, $reply_to) = wp($msg);
		if ($target =~ /^(?i)$reply_to$/)
		{
			$server->command("MSG $target $reply");
		}
		elsif (defined $reply_to)
		{
			$server->command("MSG $target $reply_to $reply");
		}
		else
		{
			$server->command("MSG $target $nick $reply");
		}
	}
}

sub wp
{
	my ($data) = @_;
	if ($data =~ /^!wp([^ ]*) (.+?)( @\s*(.*?))*\s*$/)
	{
		my ($lang, $article, $to) = ($1, $2, $4);
		$lang = (grep(/^${lang}$/, @languages)) ? $lang : "en";
		$article =~ s/ /_/g;
		return "http://${lang}.wikipedia.org/wiki/$article", $to;
		 # "${to}: http://${lang}.wikipedia.org/wiki/$article"
	}
	else
	{
		print "Error: @_";
		return 0;
	}
}

