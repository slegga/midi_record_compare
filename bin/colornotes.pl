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
#option 'allowstacato!','Accept and marks notes as stacato if they look like that',{default=>0};

sub main {
    my $self = shift;
    my ($tunefile) = ($self->extra_options)[0];
    my $tune = Model::Tune->from_note_file($tunefile);
    my $new_scale;
    warn $tune->scale;
    if ($self->scale) {
        $new_scale = $self->scale;
    } elsif( $tune->scale) {
    	$new_scale = $tune->scale;
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
	my $d =  File::Modified->new(files=>[$tunefile,$0]);
    while (1) {
    	my (@changed) =$d->changed;
    	#say @changed;
		if ( @changed ) {
		    my $tune = Model::Tune->from_note_file($tunefile);
			say "\n";
   			$self->print_colornotes($tune);
   			$d->update();
		}
        last if $self->nowait;
		sleep(1);
   }
}

sub print_colornotes {
	my $self = shift;
	my $tune  = shift;
   	# look back to se if ok
	#my $int_of_beats = $tune->get_num_of_beats,
  	my $beat_size = $tune->denominator;
	my $data = $tune->to_data_split_hands();
#	warn join(', ',@{$tune->allowed_note_types}) if ref ;
	my $stacato = ref $tune->allowed_note_types &&  grep {$_ eq 'stacato' } @{ $tune->allowed_note_types };
#	warn $stacato;
    # code for split left and right
    for my $hand(qw/left right unknown/) {
        for my $i(0 .. $#{ $data->{$hand} } ) {
            # Add silence flag to note.
            my $note = $data->{$hand}->[$i];
            my $next_note = $data->{$hand}->[$i + 1];
            my $beat_int = $note->startbeat->to_int;
            my $next_int = defined $next_note ? $next_note->startbeat->to_int :
                $beat_int + $note->length_numerator;# last note
            if ($next_int != $beat_int + $note->length_numerator && defined $next_note) {
                if ($stacato && $next_int == $beat_int + 2 * $note->length_numerator ) {
                    $note->stacato(1);
                } elsif ( $next_note->startbeat->to_int == $beat_int
                	&& $next_note->length_numerator == $note->length_numerator ) {
                	# accord maybe mark as accord. $prev_note->
                } else {
#                warn sprintf"%s == %s - %s",$prev_note->length_numerator,$beat_int,$exp_beat_int;
                    $note->next_silence( $next_int - $beat_int + $note->length_numerator);
                }
            }
            $note->hand($hand);
    	}
    }

	# info
	for my $k (qw/comment denominator startbeat allowed_note_lengths allowed_note_types scale hand_left_max hand_right_min/) {
		printf"%-15s %-30s\n",$k,(ref $tune->$k? join(',',@{$tune->$k}):$tune->$k) if $tune->$k;
		}
	my $allow_all_pause_lengths=0;
	$allow_all_pause_lengths = scalar grep {$_ eq 'all_pause_lengths'} @{ $tune->allowed_note_types } if ref $tune->allowed_note_types eq 'ARRAY';

#	say color('red').$allow_all_pause_lengths.color('reset');
    # splice hands
	my @handsplice = sort {$a->order <=> $b->order} ( @{$data->{left}}, @{ $data->{right} }, @{$data->{unknown}});

	for my $n( @handsplice) {
	    #Delay
        if(!defined $n->next_silence || $n->next_silence == 0) {
            print color('green');
        } elsif ($n->next_silence > 0 && ! $n->stacato) {
            print color('yellow');
        } elsif ($n->next_silence < 0  && ! $n->stacato) {
            print color('bright_green');
        } else {
            print color('bright_red');
        }

        # note end in another beat or later than the beginning
        if( 1+int($n->startbeat->to_int/$tune->denominator)<($n->startbeat->to_int + $n->length_numerator)/$tune->denominator ) {
            my $t= ($n->startbeat->to_int + $n->length_numerator)/$tune->denominator;
            if($t - int $t) {
            	if (! $n->note<0 || ! $allow_all_pause_lengths) {
	                print color('magenta');
	            }
            }
        }

        #if($n->length_numerator $n->length_numerator)
        # legg inn sjekk på at note ikke overskriver takt.
        # farg magnetta

        # allowed_note_lengths
        if (ref $tune->allowed_note_lengths eq 'ARRAY') {
            if (! grep {$n->length_numerator == $_}
                @{ $tune->allowed_note_lengths }) {
                if ($n->note>= 0 || ! $allow_all_pause_lengths ) {
	                print color('red');
	            }
            }
        }
        if (!defined $n->hand ||$n->hand eq 'unknown') {
        	print color('cyan');
        }
        print $n->to_string({scale=>$tune->{scale}}),"\n";
        print color('reset');
    }
    print color('reset');
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
