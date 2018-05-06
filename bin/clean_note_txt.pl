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
Can change scale.

=cut

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list' ],
    [ 'scale', 'Set scale. Convert from old to given scale. Example c_dur'],
    [ 'ticsprbeat', 'Number of tics. Examle 6.'],
,{return_uncatched_arguments => 1});

my $tune = Model::Tune->from_note_file($ARGV[0]);
#$tune->spurt;
my $new_scale;
if ($opts->scale) {
    $new_scale = $opts->scale;
} else {
    $new_scale = Model::Utils::Scale::guess_scale_from_notes($tune->notes);
}
if ($new_scale ne $tune->scale) {
    $tune->scale($new_scale);
}

if ($opts->ticsprbeat) {
    $tune->denominator($opts->ticprbeat);
}

say "$tune";
$tune->to_note_file; # will write notes based on $tune->scale
