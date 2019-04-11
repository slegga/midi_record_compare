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

option 'extend=s', 'Extend these periods to next valid length. Takes , separated list';
option 'scale=s', 'Set scale. Convert from old to given scale. Example c_dur';
option 'ticsprbeat=i', 'Number of tics. Examle 6.';
option 'reduce_octave!', 'Move tune one octave down';

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
	if ($self->reduce_octave) {
        my @new_notes;
		for my $n(@{$tune->notes}) {
			$n->note($n->note -12);
		}

	}

    if ($self->ticsprbeat) {
        $tune->denominator($self->ticprbeat);
    }

    say "$tune";
    $tune->to_note_file; # will write notes based on $tune->scale
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
