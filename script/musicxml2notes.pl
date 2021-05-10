#!/usr/bin/env perl

=head1 NAME

xml-test.pl

=head1 DESCRIPTION

Manual Test on do xml to hash

=cut

use Mojo::Base -strict,-signatures;
use Data::Printer {max_depth=>10};
use Mojo::File 'path';
use Data::Dumper;
use XML::Writer;
use Mojo::JSON 'j';

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use SH::UseLib;
#use Music::Utils::Scale;
use Music::Tune;
use Mojo::File 'path';

use Carp::Always;

my $tune = Music::Tune->from_string(path($ARGV[0])->slurp);
$tune->notes2score;
say $tune->to_musicxml_text;

