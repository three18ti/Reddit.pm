package Reddit;

our $VERSION = '0.20.moose';

use 5.012004;
use Data::Dumper;

use common::sense;

use JSON;
use HTTP::Cookies;
use LWP::UserAgent;

use Moose;

has 'base_url' => (
	is	=> 'ro',
	isa => 'Str',
	default => 'http://www.reddit.com/',
);

has 'api_url' => (
	is	=> 'ro',
	isa => 'Str',
	lazy	=> 1,
	default => sub { $_[0]->base_url . 'api/' },
);

has 'login_api' => (
	is => 'ro',
	isa => 'Str',
	lazy	=> 1,
	default => sub { $_[0]->api_url . 'login' },
); 

has 'submit_api' => (
	is => 'ro',
	isa => 'Str',
	lazy	=> 1,
	default => sub { $_[0]->api_url . 'submit' },	
);

has 'comment_api' => (
	is => 'ro',
	isa => 'Str',
	lazy	=> 1,
	default => sub { $_[0]->api_url . 'comment' },	
);

has 'api_type'	=> (
	is => 'ro',
	isa => 'Str',
	default => 'json',
);

has 'ua' => (
    is  => 'rw',
    isa => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new },
#    handles => qr/^(?:head|get|post|agent|request.*)/,
	handles => { 
		post				=> 'post',
		agent_cookie_jar 	=> 'cookie_jar' 
	}
);

has 'cookie_jar' => (
	is => 'rw',
	isa => 'HTTP::Cookies',
	lazy => 1,
	default => sub { HTTP::Cookies->new },	
);

has [ 'user', 'passwd', ] => (
	is => 'rw',
	isa => 'Str',
	required => 1,	
	trigger => \&_login,
);

has 'subreddit' => (
	is => 'rw',
	isa => 'Str',
);

has 'modhash' => (
	is => 'rw',
	isa => 'Str',
);

sub _login {
	my $self = shift;
	
	my $response = $self->ua->post($self->login_api,
        {
            api_type    => $self->api_type,
            user        => $self->user,
            passwd      => $self->passwd,
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
    $self->modhash ($decoded->{json}{data}{modhash});
}

sub _parse_link {
    my $self = shift;
    my $link = shift;

    my ($id) = $link =~ /comments\/(\w+)\//i;
    return 't3_' . $id;
}

# Submit link to reddit
sub submit_link {
    my $self = shift;
    my ($title, $url, $subreddit) = @_;

    my $kind        = 'link';

    my $newpost     = $self->ua->post($self->submit_api,
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
    my $link = $decoded->{jquery}[18][3][0];
    my $id = $self->parse_link($link);

    return $id, $link;
}

sub submit_story {
    my $self = shift;
    my ($title, $text, $subreddit) = @_;
 
    my $kind        = 'self';
    my $newpost     = $self->post($self->submit_api,
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

    #returns id and link to new post if successful
    my $link = $decoded->{jquery}[12][3][0];
    my $id = $self->_parse_link($link);

    return $id, $link;
}

sub comment {
    my $self = shift;
    my ($post_id, $comment) = @_;

    my $response = $self->ua->post($self->comment_api,
        {
            thing_id    => $thing_id,
            text        => $comment,
            uh          => $self->modhash,
        },
    );

    my $decoded = from_json $response->content;
    return $decoded->{jquery}[18][3][0][0];
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
