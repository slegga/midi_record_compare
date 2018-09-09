#!/usr/bin/env perl

use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
#use Carp::Always;
use Model::Tune;

=head1 NAME

 - cleanup a note txt file

=head1 DESCRIPTION

Ment to be used to convert samples to blueprints.
Remove comments and add new ones.
Can change scale.

=cut

option 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list';
option 'scale', 'Set scale. Convert from old to given scale. Example c_dur';
option 'ticsprbeat', 'Number of tics. Examle 6.';
#,{return_uncatched_arguments => 1});
 sub main {
    my $self = shift;
    my @e = $self->extra_options;
    say Dumper \@e;
    my $filename = ($self->extra_options)[0];
    die "No file given" if ! $filename;
    my $tune = Model::Tune->from_note_file($filename);
    my $new_scale;
    if ($self->scale) {
        $new_scale = $self->scale;
    } else {
        $new_scale = Model::Utils::Scale::guess_scale_from_notes($tune->notes);
    }
    if ($new_scale ne $tune->scale) {
        $tune->scale($new_scale);
    }

    if ($self->ticsprbeat) {
        $tune->denominator($self->ticprbeat);
    }

    say "$tune";
    $tune->to_note_file; # will write notes based on $tune->scale
}

__PACKAGE__->new->with_options->main() if !caller;;
1;
