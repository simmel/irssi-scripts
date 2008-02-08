sub DEBUG { 0 }
use strict;
#use warnings;
if (DEBUG) { eval "use Data::Dumper"; }
use Data::Dumper;
use Irssi;
use URI::Escape;
use LWP::UserAgent;
use HTML::Entities;
use Encode;
use vars qw($VERSION %IRSSI);

$VERSION = "2.0";
%IRSSI = (
	authors => "Simon 'simmel' Lundström",
	contact => "simmel@(undernet|quakenet|freenode|efnet)",
	name    => "google",
	description => "An script which answers to !g[oogle][.<language>] <query> [@[ ]<nickname to tell it to>]",
	license => "BSDw/e, but please send bugs/improvements/suggestions/nuts/soda to me",
	url     => "http://soy.se/code/",
	changed => "2007-05-12"
);

# Thanks:
# * mauke #perl@freenode for s/\\x([[:xdigit:]]{1,2})/chr hex $1/ge

# CHANGELOG
# 2.0 Added googlefight and all kinds of searches.
# 1.0 first version based on my wp.pl

# TODO
# Start using $response->decoded_content.
# If $reply_to is me then tell them something malicious.

# http://www.google.com/language_tools#domains
our %languages = ( # {{{
	"en", "com",
	"ae", "ae",
	"af", "com.af",
	"ag", "com.ag",
	"ai", "off.ai",
	"am", "am",
	"ar", "com.ar",
	"as", "as",
	"at", "at",
	"au", "com.au",
	"az", "az",
	"ba", "ba",
	"bd", "com.bd",
	"be", "be",
	"bg", "bg",
	"bh", "com.bh",
	"bi", "bi",
	"bo", "com.bo",
	"br", "com.br",
	"bs", "bs",
	"bw", "co.bw",
	"bz", "com.bz",
	"ca", "ca",
	"cd", "cd",
	"cg", "cg",
	"ch", "ch",
	"ci", "ci",
	"ck", "co.ck",
	"cl", "cl",
	"cn", "cn",
	"co", "com.co",
	"cr", "co.cr",
	"cu", "com.cu",
	"cz", "cz",
	"de", "de",
	"dj", "dj",
	"dk", "dk",
	"dm", "dm",
	"do", "com.do",
	"ec", "com.ec",
	"ee", "ee",
	"eg", "com.eg",
	"es", "es",
	"et", "com.et",
	"fi", "fi",
	"fj", "com.fj",
	"fm", "fm",
	"fr", "fr",
	"ge", "ge",
	"gg", "gg",
	"gi", "com.gi",
	"gl", "gl",
	"gm", "gm",
	"gr", "gr",
	"gt", "com.gt",
	"gy", "gy",
	"hk", "com.hk",
	"hn", "hn",
	"hr", "hr",
	"ht", "ht",
	"hu", "hu",
	"id", "co.id",
	"ie", "ie",
	"il", "co.il",
	"im", "co.im",
	"in", "co.in",
	"is", "is",
	"it", "it",
	"je", "co.je",
	"jm", "com.jm",
	"jo", "jo",
	"jp", "co.jp",
	"ke", "co.ke",
	"kg", "kg",
	"kr", "co.kr",
	"kz", "kz",
	"li", "li",
	"lk", "lk",
	"ls", "co.ls",
	"lt", "lt",
	"lu", "lu",
	"lv", "lv",
	"ly", "com.ly",
	"ma", "co.ma",
	"md", "md",
	"mn", "mn",
	"ms", "ms",
	"mt", "com.mt",
	"mu", "mu",
	"mw", "mw",
	"mx", "com.mx",
	"my", "com.my",
	"na", "com.na",
	"nf", "com.nf",
	"ng", "com.ng",
	"ni", "com.ni",
	"nl", "nl",
	"no", "no",
	"np", "com.np",
	"nr", "nr",
	"nu", "nu",
	"nz", "co.nz",
	"om", "com.om",
	"pa", "com.pa",
	"pe", "com.pe",
	"ph", "com.ph",
	"pk", "com.pk",
	"pl", "pl",
	"pn", "pn",
	"pr", "com.pr",
	"pt", "pt",
	"py", "com.py",
	"qa", "com.qa",
	"ro", "ro",
	"ru", "ru",
	"rw", "rw",
	"sa", "com.sa",
	"sb", "com.sb",
	"sc", "sc",
	"se", "se",
	"sg", "com.sg",
	"sh", "sh",
	"si", "si",
	"sk", "sk",
	"sn", "sn",
	"sm", "sm",
	"sv", "com.sv",
	"th", "co.th",
	"tj", "com.tj",
	"tm", "tm",
	"to", "to",
	"tp", "tp",
	"tr", "com.tr",
	"tt", "tt",
	"tw", "com.tw",
	"ua", "com.ua",
	"ug", "co.ug",
	"uk", "co.uk",
	"uy", "com.uy",
	"uz", "co.uz",
	"vc", "com.vc",
	"ve", "co.ve",
	"vg", "vg",
	"vi", "co.vi",
	"vn", "com.vn",
	"vu", "vu",
	"ws", "ws",
	"za", "co.za",
	"zm", "co.zm",
);
# }}}

our $encoding = "iso-8859-1";
our @tlds = keys %languages;

our @useragents = ( # {{{
	HTTP::Headers->new(
		'Accept' => '*/*',
		'Accept-Language' => 'en-us',
		'Accept-Encoding' => ' deflate',
		'User-Agent' => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 2.0.50727)',
		'Connection' => 'keep-alive',
	),
	HTTP::Headers->new(
		'User-Agent' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.1.1) Gecko/20070106 Firefox/2.0.0.1',
		'Accept' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
		'Accept-Language' => 'en-us,en;q=0.5',
		'Accept-Encoding' => 'deflate',
		'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
		'Keep-Alive' => '300',
		'Connection' => 'keep-alive',
	),
	HTTP::Headers->new(
		'Accept' => '*/*',
		'Accept-Language' => 'en',
		'Accept-Encoding' => 'deflate',
		'User-Agent' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/418.9.1 (KHTML, like Gecko) Safari/419.3',
		'Connection' => 'keep-alive',
	),
);
# }}}

Irssi::signal_add_last("message public", "msg_pub_event");
Irssi::signal_add_last("message private", "msg_pub_event");

sub msg_pub_event
{
	my ($server, $msg, $nick, $address, $target) = @_;
	if ($msg =~ /^!g(?:oogle)?\.?f(?:ight)? (("?).+?\2) (("?).+?\4)(?: @\s*(.*?))*\s*$/)
	{
		my $reply = google_fight($1, $3);
		my $reply_to = $5;
		if (defined $reply_to)
		{
			$server->command("MSG $target $reply_to $reply");
		}
		else
		{
			$server->command("MSG $target $nick $reply");
		}
	}
	elsif ($msg =~ /^!g(?:oogle)*\.*(\w{2,3}(?:\.\w{2})?)*?\.?(im(?:g|age))?\.?(sum|url|desc)?\[?(\d)?\]? (.+?)(?: @\s*(.*?))*\s*$/)
	{
		my ($reply) = google($1, $2, $3, $4, $5, $6);
		my $reply_to = $6;
		if (defined $reply_to)
		{
			$server->command("MSG $target $reply_to $reply");
		}
		else
		{
			$server->command("MSG $target $nick $reply");
		}
	}
}

sub google_fight
{
	my @words = @_[0..1];
	my @words_escaped = map { uri_escape($_); } @words;

	my $url = "http://googlefight.com/query.php?lang=en_GB&word1=${words_escaped[0]}&word2=${words_escaped[1]}";
	my $content;

	my $browser = LWP::UserAgent->new;
	my $response = $browser->get($url);
#	TODO $response->decoded_content
	if ($response->is_success) {
		$content = $response->content;
	}
	else {
		print Dumper $response;
		print Dumper $response->status_line;
		return;
	}
	$content =~ s!.*<tr>(.*?)</tr>.*!$1!s;
	my @content = grep(/<span>/, split('\n', $content));
	map { s!.*<span>(.*?) \w+</span>.*!$1! } @content;

	return "${words[0]} vs. ${words[1]} - ${content[0]} : ${content[1]}";
}

sub google
{
	our ($lang, $method, $attr, $index, $query, $reply_to, $tld, $content) = (@_, undef, undef);

	print Dumper "lang:".$lang, "method:".$method, "attr:".$attr, "index:".$index, "query:".$query, "replyto:".$reply_to;
	our (@result, $url, $engine, $content) = undef;

	$lang = (grep(/^${lang}$/, @tlds)) ? $lang : "en";
	$tld = $languages{$lang};
	$query = uri_escape($query);

	if ($method =~ /^im(?:g|age)/)
	{
		$method = "image";
		$engine = "images";
	}
	else
	{
		$engine = "search";
	}

	$url = "http://www.google.$tld/$engine?hl=$lang&rls=$lang&oe=$encoding&q=$query";
	print $url if (DEBUG);
	my $rnd = rand(scalar @useragents);
	$rnd = int $rnd;
	my $useragent = @useragents[$rnd];
	print $useragent->header('User-Agent') if (DEBUG);

	my $browser = LWP::UserAgent->new;
	$browser->agent($useragent->header('User-Agent'));
	$browser->default_headers($useragent, $useragent);
	my $response = $browser->get($url);
#	TODO $response->decoded_content
	if ($response->is_success) {
		$content = $response->content;
	}
	else {
		print Dumper $response;
		print Dumper $response->status_line;
		return;
	}

	@result = split(/\n/, $content);

	if ("@result" =~ /calc_img\.gif.+?<b>(.+?)<\/b>/)
	{
		print "calc!" if (DEBUG);
		$method = "calc";
		@result = $1;
	}

	if ($attr eq "url")
	{
		print "url!" if (DEBUG);
		@result = ($url);
		undef $index;
	}
#	elsif ($method =~ /^im(?:g|age)/)
	elsif ($method eq "image")
	{
		print "image!" if (DEBUG);
		@result = grep(/window\.dyn = /, @result);
		my $result = "@result";
		@result = split(/dyn\.Img/, $result);
		shift(@result);
		@result = map { "$1 $2" if /.*?(http:\/\/[^"]+\.\w{3,4})","\d+","\d+","(.+?)".*/; } @result;
	}
	elsif ($attr eq "desc" && $method !~ /image|calc/)
	{
		print "desc!" if (DEBUG);
		@result = grep(/<\/script><table/, @result);
		my $result = "@result";
#		@result = split(/<!--[mn]-->/, $result);
		@result = split(m!<div class=g>!, $result);
		shift(@result);
		@result = map { "$1 $2: $3" if /.*?(http:\/\/[^"]+).* class=l>(.*?)<\/h2>.*<font size=-1>(.*?)<br><span class=a>.*/s; } @result;
#		@result = map { s!.*?(http://[^"]+).* class=l>(.*?)</h2>.*<font size=-1>(.*?)<br><span class=a>.*!$1 $2: $3!s; } @result;
	}
	elsif ($method !~ /image|calc/)
	{
		print "else!" if (DEBUG);
		@result = grep(/<\/script><table/, @result);
		my $result = "@result";
		@result = split(/\<!--[mn]--\>/, $result);
		@result = split(/\<div class=g\>/, $result);
		shift(@result);
		map { s/.*?(http:\/\/[^"]+).*/$1/s; } @result;
	}

	if ($attr =~ /^sum(?:mary)?/ && $method !~ /calc/)
	{
		print "summary!" if (DEBUG);
		$index = "0-4";
	}
	elsif ($method eq "image" && $attr !~ /sum(?:mary)?|desc/)
	{
		map { s/^([^ ]+) .*/$1/; } @result;
	}

	if (!defined $index)
	{
		print "no index!" if (DEBUG);
		@result = ($result[0]);
	}
	elsif ($index =~ /\d-(\d)/)
	{
		print "ranged index!" if (DEBUG);
		while (scalar @result > $1+1)
		{
			pop @result;
		}
		@result = (join(" ", @result));
	}
	else
	{
		print "specific index $index!" if (DEBUG);
		@result = $result[$index];
	}
#	Strip HTML
	@result = map { uri_unescape($_); $_; } @result;
	@result = map { s/\\x([[:xdigit:]]{1,2})/chr hex $1/ge; $_; } @result;
	@result = map { s/<[^>]*>//g; $_; } @result;
	if ("@result" eq "")
	{
		print Dumper $response if (DEBUG);
		return "No result.";
	}
	else
	{
		return "@result";
	}
}
