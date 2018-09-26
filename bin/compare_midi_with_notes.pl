#!/usr/bin/env perl

use FindBin;
#use Data::Dumper;
#use Algorithm::Diff;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Model::Tune;

=head1 NAME

tune_compare.pl - Compare mid-file with a blueprint

=head1 DESCRIPTION

Compare played song as midi file with a blue print as note-text.

=cut

#,{return_uncatched_arguments => 2});

sub main {
    my $self = shift;
    my ($midifile, $tunefile) = ($self->extra_options)[0,1];
    my $tune_play = Model::Tune->from_midi_file($midifile);
    $tune_play->calc_shortest_note;
    $tune_play->score2notes;
    my $tune_blueprint= Model::Tune->from_note_file($tunefile);

    $tune_play->evaluate_with_blueprint($tune_blueprint);
    # print $tune_play->evaluation;
}

__PACKAGE__->new->main();
