#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::Script qw/options_and_usage/;

use Mojo::Base -strict;
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
#use Carp::Always;
use Model::Tune;

=head1 NAME

 - cleanup a note txt file

=head1 DESCRIPTION

Ment to be used to convert samples to blueprints.
Remove comments and add new ones.
Can change scala.

=cut

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list' ],
    [ 'scala', 'Set scala. Convert from old to given scala. Example c_dur'],
,{return_uncatched_arguments => 1});

my $tune = Model::Tune->from_note_file($ARGV[0]);
#$tune->spurt;
my $new_scala;
if ($opts->scala) {
    $new_scala = $opts->scala;
} else {
    $new_scala = $tune->find_best_scala;
}
if ($new_scala ne $tune->scala) {
    $tune->scala($new_scala);
}
say "$tune";
$tune->to_note_file;
