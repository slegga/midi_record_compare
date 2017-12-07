#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::Script qw/options_and_usage/;

use Mojo::Base -strict;
use Data::Dumper;
use Algorithm::Diff;
use Model::Tune;

=head1 NAME

tune_compare.pl - Compare mid-file with a blueprint

=head1 DESCRIPTION

Compare played song as midi file with a blue print as note-text.

=cut

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list' ],
,{return_uncatched_arguments => 2});


my $tune_play = Model::Tune->from_midi_file($ARGV[0]);
$tune_play->calc_shortest_note;
$tune_play->score2notes;
my $tune_blueprint= Model::Tune->from_note_file($ARGV[1]);

$tune_play->evaluate_with_blueprint($tune_blueprint);
# print $tune_play->evaluation;

__END__
