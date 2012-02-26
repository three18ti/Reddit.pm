#!/usr/bin/perl

use LWP::UserAgent;
use JSON;
use HTTP::Cookies;
use common::sense;
use Moose;



say 'LWP::UserAgent: ' . $LWP::UserAgent::VERSION;
say 'LWP: ' . $LWP::VERSION;
say 'JSON: ' . $JSON::VERSION;
say 'HTTP::Cookies: ' . $HTTP::Cookies::VERSION;
say 'Moose: ' . $Moose::VERSION;
say 'common::sense: ' . $common::sense::VERSION;
