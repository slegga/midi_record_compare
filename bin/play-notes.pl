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
use Mojo::File qw/path tempfile/;

=head1 DESCRIPTION

('note_on', dtime, channel, note, velocity)
dtime = a value 0 to 268,435,455 (0x0FFFFFFF)
channel = a value 0 to 15
note = a value 0 to 127
velocity = a value 0 to 127

=cut

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list' ],
,{return_uncatched_arguments => 1});
my $note_file = $ARGV[0] or die "Did not get a filename";
die "File $note_file does not exists" if ! -e $note_file;

my $tmpfile = tempfile;
my $tune = Model::Tune->from_note_file($ARGV[0]);
$tune->notes2score;
$tune->to_midi_file($tmpfile);
`timidity $tmpfile`;
