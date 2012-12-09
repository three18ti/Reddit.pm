package Reddit;
use 5.010001;

use strict;
use warnings;

use JSON;
use HTTP::Cookies;
use LWP::UserAgent;

use Mouse;

=head1 NAME

Reddit - Perl extension for http://www.reddit.com

See github for the most up to date/development branch: https://github.com/three18ti/Reddit.pm

=head1 SYNOPSIS

  use Reddit;
  
  # instantatiate a new reddit object
  # Automajically handles logging in and cookie handling
  $r = Reddit->new(
      {
          user_name => 'Foo', 
		  password  => 'Bar', 
		  subreddit => 'Perl'
	  }
  );
  # user_name, password are not required if accessing information which does not require login.

  # Submit a link
  # $title, $url, $subreddit
  # This overrides a subreddit set duriing instantiation
  $r->submit_link( 'Test', 'http://example.com', 'NotPerl');

  # Submit a Self Post
  # $title, $text, $subreddit
  # This overrides a subreddit set during instantiation
  $r->submit_story( 'Self.test', 'Some Text Here', 'shareCoding');  

  # Post a top level comment to a URL or .self post 
  $r->comment($post_id, $comment);
  
  # Post a reply to a comment
  $r->comment($comment_id, $comment);

=head1 DESCRIPTION

Perl module for interacting with Reddit.

This module is still largely inprogress.

=head2 Requires

  common::sense
  LWP::UserAgent
  JSON
  HTTP::Cookies

  For Testing:
  Data::Dumper

=head2 EXPORT

None.

=cut

has 'ua' => (
    is  => 'rw',
    isa => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new },
	handles => { 
		post				=> 'post',
		get					=> 'get',
		agent_cookie_jar 	=> 'cookie_jar' 
	}
);

has 'cookie_jar' => (
	is => 'rw',
	isa => 'HTTP::Cookies',
	lazy => 1,
	default => sub { HTTP::Cookies->new },	
);

has [ 'user_name', 'password', ] => (
	is => 'rw',
	isa => 'Str',
	required => 0,	
	trigger => \&_login,
);

has 'subreddit' => (
	is => 'rw',
	isa => 'Str',
	default => sub {'all'},
);

has 'modhash' => (
	is => 'rw',
	isa => 'Str',
);

has '_link_hash' => (
	is => 'rw',
	isa => 'HashRef',
	lazy => 0,
	default => sub {{}},
);


#-----------------------------------#
#	HIDDEN METHODS		    #
#-----------------------------------#

sub _login {
	my $self = shift;
	
	my $response = $self->ua->post('http://www.reddit.com/api/login',
        {
            api_type    => 'json',
            user        => $self->user_name,
            passwd      => $self->password,
        }
    );

    $self->_set_cookie($response);
}

sub _set_cookie {
    my $self        = shift;
    my $response    = shift;

    $self->cookie_jar->extract_cookies ($response);
    $self->agent_cookie_jar ($self->cookie_jar);
    $self->_parse_modhash ($response);
}

sub _parse_modhash {
    my $self        = shift;
    my $response    = shift;

    my $decoded = from_json ($response->content);
    $self->modhash($decoded->{json}{data}{modhash});
}

sub _parse_link {  
# Returns the ID of a link/self.post from a full url. Prepends t3_.
# Example:  www.reddit.com/r/linux/comments/14hzj3/some_title/ -> t3_14hzj3
    my $self = shift;
    my $link = shift;
    my ($id) = $link =~ /comments\/(\w+)\//i;
    return 't3_' . $id;
}

sub _unzip_hash{
# A sub which will take nested values and hashes references and pull them into global _link_hash.
# sub is used solely for &get_link_info at the moment.
	my $self = shift;
	my %oldhash = %{(shift)};
	while(my($key,$value) = each %oldhash){
		if(UNIVERSAL::isa($value, "ARRAY")){$value = @$value[0]}; 
		#^ The link json includes a needless array which contains		  
		# an array container over a reference. Simply strips array.

		if(UNIVERSAL::isa($value, "HASH")){$self->_unzip_hash($value)} #Recursive call
		else{ 
			if(!defined $value){$value = 0};
			$key .= "_sub" if(${$self->_link_hash}{$key});
			$self->_link_hash->{$key}=$value; 
			#print("\nADDING $key to _list_hash"); 
			#^ Used for debugging. Shows when (non-hash) key/value pairs are found.
		}
	}
}


sub _parse_comment_id {
    # ID's require a t3_ or t1_ prefix depending on whether it is a
    # post or comment id respectively.
	my $self = shift;
	my $id = shift;

	if ($id =~ /^t[13]_/){return $id}; #return ID unchanged if it already has prefix.

	if (length($id) == 5 || length($id) == 6){ $id = "t3_" . $id} #add prefix for link/self.post id

	elsif (length($id) == 7){ $id = "t1_" . $id} #add prefix for comment id
	
	else { warn "Unknown ID. If action does not happen, ensure ID is correct."}
	# Warn if it doesn't match anything

	return $id;
}

=head1 Provided Methods

=over 2

=item B<submit_link($title, $url, $subreddit)>

    $r->submit_link( 'Test', 'http://example.com', 'NotPerl');

This method posts links to the specified subreddit.  The subreddit parameter is optional if it is not set at the time of instantiation
$subreddit is required in one place or the other, subreddit specified here will take precedence over the subreddit specified at time of instantiation.

=back

=cut

# Submit link to reddit
sub submit_link {
    my $self = shift;
    my ($title, $url, $subreddit) = @_;

    my $kind        = 'link';

    my $newpost     = $self->ua->post('http://www.reddit.com/api/submit',
        {
            uh      => $self->modhash,
            kind    => $kind,
            sr      => $subreddit || $self->subreddit,
            title   => $title,
            r       => $subreddit || $self->subreddit,
            url     => $url,
        }
    );

    my $json_content    = $newpost->content;
    my $decoded         = from_json $json_content;

    #returns link to new post if successful
    my $link = $decoded->{jquery}[18][3][0]; # get id of your post from response
    my $id = $self->_parse_link($link); # format id correctly

    return $id, $link;
}

=over 2

=item B<submit_story($title, $text, $subreddit)>

    $r->submit_story('Title', 'Body text', 'shareCoding');

This method makes a Self.post to the specified subreddit.  The subreddit parameter is optional if it is not set at the time of instantiation
$subreddit is required in one place or the other, subreddit specified here will take precedence over the subreddit specified at time of instantiation.

=back

=cut

sub submit_story {
    my $self = shift;
    my ($title, $text, $subreddit) = @_;
 
    my $kind        = 'self';
    my $newpost     = $self->post('http://www.reddit.com/api/submit',
        {
            uh       => $self->modhash,
            kind     => $kind,
            sr       => $subreddit || $self->subreddit,
            r        => $subreddit || $self->subreddit,
            title    => $title,
            text     => $text,
        },
    );

    my $json_content    = $newpost->content;
    my $decoded         = from_json $json_content;
    

   #---------- CAPTCHA -------#
    my $captcha = $decoded->{jquery}[12][3][0];
    if($captcha eq ".error.BAD_CAPTCHA.field-captcha"){ #If given captcha 
	my $captcha_id = $decoded->{jquery}[10][3][0]; #Not used yet. Captcha id.

	die("Reddit needs you to verify a captcha in order to post.");
    }
   #Catcha will be required for accounts with low karma.
   # url for captchas: http://www.reddit.com/captcha/captcha_id.png
   # replace captcha id with value in $captcha_id

   # If you want to resubmit with captcha response:
   # 
   # 1. View the captcha by inputing above url into a browser.
   # 2. Resubmit with 2 more fields in the post:
   #	* 'iden' => $captcha_id,
   #	* 'captcha' => $value_of_captcha,
   #-------------------------#

    #returns id and link to new post if successful
    my $link = $decoded->{jquery}[10][3][0]; 
    my $id = $self->_parse_link($link);

    return $id, $link;
}

=over 2

=item B<comment($post_id, $comment)>
   
To post a top level comment to a URL or .self post 

    $r->comment($post_id, $comment);

To post a reply to a comment
    
    $r->comment($comment_id, $comment);

This methid requires you pass in the cannonical thing ID with the correct thing prefix.
Submit methods return cannonical thing IDs, L<See the FULLNAME Glossary|https://github.com/reddit/reddit/wiki/API> for futher information

The post_id is the alphanumeric string after the name of the subreddit, before the title of the post
The comment_id is the alphanumeric string after the title of the post

=back

=cut

sub comment {
    my $self = shift;
    my ($thing_id, $comment) = @_;
    $thing_id = $self->_parse_comment_id($thing_id);
    my $response = $self->post('http://www.reddit.com/api/comment',
        {
            thing_id    => $thing_id,
            text        => $comment,
            uh          => $self->modhash,
        },
    );

    my $decoded = from_json $response->content;
    return $decoded->{jquery}[18][3][0][0]->{data}{id};
}

sub get_user_info {
	my $self = shift;
	my $search_name = shift;
	my $search_url = 'http://www.reddit.com/usr/'. $search_name .'/about.json';

	my $response = $self->get ($search_url);
	my $decoded = from_json $response->content;
	my %data = %{$decoded->{data}};
	foreach(keys %data){$data{$_} = !$data{$_} ? '0' : $data{$_}} 
	return \%data;	
}

###############################################
#             _user_get			      #	
###############################################
# Template method for get_user_* methods      #
###############################################
sub _user_get {
	my $self = shift;
	my $type = shift;
	my $args = shift;
	my $user = $args->{'username'} && delete  $args->{'username'} || die("Must supply a username to get_user_$type");
	my $other = "?";
	foreach(keys %$args){$other .= ("$_" . $args->{$_} . "&")};
	my $response = $self->get("http://www.reddit.com/user/$user/$type.json$other");
	my %packaged = %{from_json($response->content)};
	my @posts;
	foreach(@{$packaged{'data'}->{'children'}}){push(@posts,$_->{'data'})};
	return @posts;
} 

###############################################
#             get_user_*		      #
###############################################
# Methods which utilize _user_get	      #
###############################################

sub get_user_overview{ 
	my $self = shift;
	return $self->_user_get("overview",shift);
}
sub get_user_comments{ 
	my $self = shift;
	return $self->_user_get("comments", shift);
}
sub get_user_submitted{ 
	my $self = shift;
	return $self->_user_get("submitted", shift);
}
sub get_user_liked{
	my $self = shift;
	return $self->_user_get("liked", shift);
}
sub get_user_disliked{
	my $self = shift;
	return $self->_user_get("disliked", shift);
}
sub get_user_saved{
	my $self = shift;
	return $self->_user_get("saved", shift);
}
#################################################

sub vote {
	my $self = shift; 
	my ($thing_id, $direction) = @_;
	
	given ($direction) {
		when ( /up/i || 1) {
			$direction = 1;
		}
		when ( /down/i || -1) {
			$direction = -1;
		}
		when ( /rescind/i || 0 ) {
			$direction = 0;
		}
		default {
			warn "Please enter a valid direction";
			return 0;
		}
	}

	$thing_id = $self->_parse_comment_id($thing_id); #adds prefix (t1_ or t3_) if necessary.
	

	my $response = $self->post ( 'http://www.reddit.com/api/vote', 
		{
			id	=> $thing_id,
			dir => $direction,
			uh	=> $self->modhash
		}
	);
	return $response->is_success;	
}

=over 2

=item B<vote($thing_id, $direction)>
   
Up/Down vote a post.

    $r->vote($thing_id,$direction);

Where $direction is one of: up, down, rescind

=back

=cut

sub get_link_info{
        my $self = shift;
	my $link = shift;
        $link = $self->_parse_link($link);
	my $response = $self->get('http://www.reddit.com/api/info.json' . "?id=$link");
	my %content_hash = %{from_json $response->content};
	$self->_unzip_hash(\%content_hash);
	return $self->_link_hash;
}

=over 2

=item B<get_link_info($reddit_url)>
   
Retreives information about a reddit url and returns it in the form of a hashref. 

    $r->get_link_info($reddit_post_url);

This method requires you submit a valid url of a reddit post. Ex: "www.reddit.com/r/gif/comments/wua4q/i_love_a_toilet_paper/"
The Reddit info api is also supports other functions, they have yet to be implemented in this module.

=back

=cut

sub get_subreddit{
	my $self = shift;
	my $args = shift;
	my $subred = ($args->{'subreddit'} || $self->subreddit || "all"); 
	my $sort = ($args->{'sort'} || "hot");
	my $other = "?sort=$sort";
	delete $args->{'sort'};
	delete $args->{'subreddit'};
	foreach(keys %$args){$other .= "&$_=" . $args->{$_}}; #fill other arguments
	my @posts;
	my $response = $self->get("http://www.reddit.com/r/$subred/$sort.json$other");
	my $container = from_json($response->content);
	push (@posts, $_->{'data'}) foreach @{$container->{'data'}->{'children'}};
	return @posts;
}

=over 2

=item B<get_subreddit()>
   
Retreives posts from a subreddit and returns it in the form of an array of hashrefs.
Each hashref contains the information of an individual post.

	$r->get_subreddit({'sort'=>'new','limit'=>'30','subreddit'=>'perl'});
	$r->get_subreddit()

Acceptable keys are: sort, limit, subreddit, before, after, show, count, target. Refer to the Reddit api for more information concerning their purpose.

This method will default to the first 25 hot sort from the 'all' subreddit (unless $self->$subreddit is defined - in which case it will use that value).

=back

=cut

sub get_comments{
	my $self = shift;
	my $args = shift;
	my $id = $args->{'id'};
	delete $args->{'id'};
	my $other = "?";
	foreach(keys %$args){$other .= "$_=" . $args->{$_} . "&"}; #fill other arguments
	my $response = $self->get("http://www.reddit.com/comments/$id.json$other");
	# $response is an arrayref.
	my @sort = @{from_json($response->content)};
	$sort[0] = @{$sort[0]->{'data'}->{'children'}}[0]->{'data'};
	# ^ Removes empty containers from post info.
	$sort[1] = $sort[1]->{'data'}->{'children'};
	# ^ Removes empty container from top level reply info. Subsequent levels remain.
	return \@sort;
	
	#!! Unique return. Returns a 2 element Arrayref.
	# $sort[0] contains a hashref of link post info. (This is redundant with &get_link_info)
	# $sort[1] contains an arrayref of reply info. Each top level post is an element.
	#	Replies to replies are in the 'reply' hash key. It nests itself. 
	# Ex: ${$a}[1][0]->{'data'}->{'body'}
	#   ^ Contains text of first top level comment.
	# Ex: ${$a}[1][0]->{'data'}->{'replies'}->{'data'}->{'children'}[0]->{'data'}->{'body'}
	#  ^ Contains the first response to the first top level comment.
	# The empty containers make it longer than it should be, but potentially parsing
	# and removing thousands of these comments did not seem like a very efficient task for 
	# the payoff.
}
=over 2

=item B<get_comments({'id'=>'11xyiy', 'sort'=>'new', 'limit'=>20, 'depth'=>4,)>

Returns the comments of a post in the form of a 2 element arrayref.

First element contains original post info. 
	Ex: ${$a}[0]->{'selftext'}; #Will return selftext of the article/post.

Second element contains reply info.
	Ex: ${$a}[1][0]->{'data'}->{'body'}; #Will return first top level comment to article.

Replies are nested under their parent post via the 'replies' hash key value.
	Ex: ${$a}[1][1]->{'data'}->{'replies'}->{'data'}->{'children'}[0]->{'data'}->{'body'};
	# Will return first reply to second top level comment. 
Examples:

=back

=cut
	

sub username_available{
	my $self = shift;
	my $user = shift;
	my $response = $self->get("http://www.reddit.com/api/username_available.json?user=$user");
	return $response->content;
}
=over 2

=item B<username_available($username)>

Checks username availability. Returns 'true' for available and 'false' for unavailable.   

	$r->username_available('billy_bob_joe')

=back

=cut


no Mouse;
__PACKAGE__->meta->make_immutable;

1;
__END__


=head1 SEE ALSO

L<https://github.com/reddit/reddit/wiki>

=head1 AUTHOR

Jon A, E<lt>info[replacewithat]cyberspacelogistics[replacewithdot]comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by jon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
