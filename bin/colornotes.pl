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
use Data::Printer;
use Clone 'clone';

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
option 'nowait!','No waiting',{default=>0};

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
        last if $self->nowait;
		select undef, undef, undef, 1;
   }
}

sub print_colornotes {
	my $self = shift;
	my $tune  = shift;
   	# look back to se if ok
	#my $int_of_beats = $tune->get_num_of_beats,
  	my $beat_size = $tune->denominator;
	my $data = $tune->to_data_split_hands();
    # code for split left and right

    for my $hand(qw/left right/) {
        my $exp_beat_int=0;
        for my $note( @{ $data->{$hand} } ) {
            # Add silence flag to note.
            my $beat_int = $note->startbeat->to_int;
            if ($beat_int != $exp_beat_int) {
                $note->prev_silence( $beat_int - $exp_beat_int);
            }
            $note->hand($hand);
            $exp_beat_int = $beat_int + $note->length_numerator;
    	}
    }

    # splice hands
    my @handsplice = sort {$a->order <=> $b->order} ( @{$data->{left}}, @{ $data->{right} });

     for my $n( @handsplice) {
        if ($n->prev_silence) {
            print color('yellow');
        } else {
            print color('green');
        }
        print $n->to_string,"\n";
    }
    print color('reset');
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
