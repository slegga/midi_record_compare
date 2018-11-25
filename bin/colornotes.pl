#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Mojo::File 'path';
use Term::ANSIColor;
use Model::Tune;
use File::Modified;

=head1 NAME

colornotes.pl - Print notes with error coloring

=head1 DESCRIPTION

Read lines and print with diffrent colors based on if it looks right or not.

=over

=item green - Looks ok

=item red - Miss first beat into tempo

=item yellow - stacato



=back

=head2 DESIGN

Leser inn tune. Rekalkulerer.
Markerer left/right per note.


=cut

#,{return_uncatched_arguments => 2});
option 'extend=s', 'Extend these periods to next valid length. Takes , separated list';
option 'scale=s', 'Set scale. Convert from old to given scale. Example c_dur';
option 'ticsprbeat=i', 'Number of tics. Examle 6.';


sub main {
    my $self = shift;
    my ($tunefile) = ($self->extra_options)[0];
    my $tune = Model::Tune->from_note_file($tunefile);
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
   	$self->print_colornotes($tune);
	my $d =  File::Modified->new(files=>[$tunefile]);
    while (1) {
    	my (@changed) =$d->changed;
		if ( @changed ) {
   			$self->print_colornotes($tune);
   			$d->update();
		}
		select undef, undef, undef, 1;
   }
}

sub print_colornotes {
	my $self = shift;
	my $tune  = shift;
   	# code for split left and right
   	# split
  	# look back to se if ok
	my $num_of_beats = $tune->get_num_of_beats,
  	my $beat_size = $tune->denominator;

	my $data = $tune->to_data_split_hands();
    for my $beat(0 .. $num_of_beats) {
    	for my$part(0 .. $beat_size) {
    		if ( $beat == 0 && $part > $self->delta_beat_score ) {
    			next;
    		}
    		my $left  = $data->{left}->[ $beat]->[$beat_size];
    		my $right = $data->{right}->[$beat]->[$beat_size];
   			# TODO: bright_red if pause.
    		printf "%3d%2d %s %s\n",$beat,$part, $left, $right;
		    print color('reset');
		}
    }

}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
