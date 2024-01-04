#!/usr/bin/env perl

use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
#use Carp::Always;
use Music::Tune;
use Mojo::File 'path';

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
    my $file = path($self->extra_options->[0]);
    die "No file given" if ! "$file";
    die "Not a file.. $file" if ! -f "$file";
    my $tune = Music::Tune->from_string($file->slurp,{ignore_end=>1});
    if (! $tune->name) {
    	my $tmp = $file->basename('.txt');
    	$tmp = uc(substr($tmp,0,1)).substr($tmp,1);
    	$tune->name($tmp);
    }
    my $new_scale;
    if ($self->scale) {
        $new_scale = $self->scale;
    } else {
        $new_scale = Music::Utils::Scale::guess_scale_from_notes($tune->notes);
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
    $file->spew($tune->to_string); # will write notes based on $tune->scale
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
