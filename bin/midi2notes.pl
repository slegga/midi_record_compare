#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
#use SH::Script qw/options_and_usage/;
use SH::ScriptX; # calls import

use Mojo::Base 'SH::ScriptX';
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
#use Carp::Always;
use Model::Tune;

=head1 NAME

midi2notes.pl

=head2 SYNOPSIS

midi2notes.pl my-midifile.mid >my-notefile.txt

=head1 DESCRIPTION

Read a midi file and output to stdout notes.

('note_on', dtime, channel, note, velocity)
dtime = a value 0 to 268,435,455 (0x0FFFFFFF)
channel = a value 0 to 15
note = a value 0 to 127
velocity = a value 0 to 127

=cut


option  'extend|e=s', 'Extend these periods to next valid length. Takes , separated list';
#,{return_uncatched_arguments => 1});
__PACKAGE__->new->with_options(forward_uncatched_arguments=>1)->main();
sub main {
	my $self=shift;
	my $tune = Model::Tune->from_midi_file(@SH::ScriptX::_extra);
	$tune->calc_shortest_note;
	$tune->score2notes;
	$tune->clean($self->extend);
	say "$tune";
}
