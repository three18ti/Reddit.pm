#!/usr/bin/perl -w

use strict;
use LWP;
use HTTP::Cookies;
use URI::Escape;
use Reddit;
use JSON;
#my $browser = LWP::UserAgent->new();

#my $cookie_jar = HTTP::Cookies->new( file => "/home/koni/PROGRAMMING/TESTING/lwp_cookies.txt",autosave =>1,);
#$browser->cookie_jar($cookie_jar);

#my $modhash = "z4gao0i1c8873973a8f1917a1cdf9467e9f1f9cad54eb9bcd7";
#my $username = "perl_bot";
#my $response;


# LOGIN
#$response = $browser->post("http://www.reddit.com/api/login/$username", ["user"=>$username, "passwd"=>"holycow22", "api_type"=> "json"]);

#print "\nLogin: " . $response->content . "\n\n";

#$modhash = $1 if($response->content =~ m/"modhash": "([^"]*)/) or die "BAD MODHASH PARSE\n";

#$browser->cookie_jar($cookie_jar);


#VOTE
#$response = $browser->post("http://www.reddit.com/api/vote", ["id" => 't3_wip3b', "dir" => 1, "uh" => $modhash]);
#print "::Vote::\nCODE: " . $response->code . "\n\n";
#print $response->content;

#INFO
#my $site = uri_escape('i.imgur.com/tvC2M.png');
#$site = 't3_wlura';
#print $site;
#$response = $browser->get("http://www.reddit.com/api/info.json?id=$site");

#print $response->content;

my $red = Reddit->new({user_name=>'perl_bot',password=>'holycow22'});

my $js = '{"kind": "Listing", "data": {"modhash": "cext57b5qpa11e46275e867efdbac55fa3db1348b33046cfa9", "children": [{"kind": "t3", "data": {"domain": "guardian.co.uk", "banned_by": null, "media_embed": {}, "subreddit": "science", "selftext_html": null, "selftext": "", "likes": null, "link_flair_text": null, "id": "wlv42", "clicked": false, "title": "The government is to unveil controversial plans to make publicly funded scientific research immediately available for anyone to read for free by 2014", "num_comments": 741, "score": 3588, "approved_by": null, "over_18": false, "hidden": false, "thumbnail": "", "subreddit_id": "t5_mouw", "edited": false, "link_flair_css_class": null, "author_flair_css_class": null, "downs": 13636, "saved": false, "is_self": false, "permalink": "/r/science/comments/wlv42/the_government_is_to_unveil_controversial_plans/", "name": "t3_wlv42", "created": 1342409518.0, "url": "http://www.guardian.co.uk/science/2012/jul/15/free-access-british-scientific-research", "author_flair_text": null, "author": "usrname42", "created_utc": 1342384318.0, "media": null, "num_reports": null, "ups": 17224}}], "after": null, "before": null}}';

#`echo $js > wowza.txt`;

#print keys %{from_json $js};
#my %phash;

#my %oldhash = %{from_json $js};

#&_unzip_hash(\%oldhash,\%phash);
#print keys ${from_json $js}{'data'};


#my %z = $red->get_user_info("whiteychs");
#while(my($key,$value) = each %z){ print("\n$key = $value")};

#our %newhash;

my $wow = $red->get_link_info("www.reddit.com/r/science/comments/wlv42/the_government_is_to_unveil_controversial_plans/");

foreach(keys %$wow){ print("$_ = " . ${$wow}{$_} . "\n")};

{
sub _unzip_hash{
	my %newhash;
	# A sub which will take nested values and hashes references and pull them into one large (global) hash. 
	my %oldhash = %{(shift)};
	while(my($key,$value) = each %oldhash){
		if(UNIVERSAL::isa($value, "ARRAY")){$value = @$value[0]}; # The link format includes a needless array which contains
									  # an array container over a reference. Simply strips array.

		if(UNIVERSAL::isa($value, "HASH")){&_unzip_hash($value)} #Recursive call
		else{ 
			$value = 0 if(!defined $value);
			$key .= "_sub" if(defined $newhash{$key});
			$newhash{$key}=$value; 
			print("\nADDING $key to newhash"); # Used for debugging. Shows when (non-hash) key/value pairs are found.
		}
	}
	#print("\nnewhash keys = " . (keys %newhash) . "\n");
}

#foreach(keys %newhash){print("\n $_ = " . $newhash{$_} . "")}
}
