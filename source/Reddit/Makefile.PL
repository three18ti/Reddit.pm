use inc::Module::Install;

name     'Reddit';
all_from 'lib/Reddit.pm';
author   q{Jon A <three18ti@gmail.com>};
license  'perl';

build_requires 'Test::More';

requires 'LWP'              => '6.02';
requires 'LWP::UserAgent'   => '6.02';
requires 'JSON'             => '2.53';
requires 'HTTP::Cookies'    => '6.00';
requires 'Moose'            => '2.0200';
requires 'common::sense'    => '3.4';

auto_install;

WriteAll;

