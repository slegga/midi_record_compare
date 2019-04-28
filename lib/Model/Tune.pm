package Model::Tune;
use Mojo::Base -base;
use Mojo::File 'path';
use Model::Note;
use Model::Beat;
use Model::Utils;
use Model::Utils::Scale;
use Data::Dumper;
use Mojo::JSON 'to_json';
use MIDI;

use Carp;
use List::Util qw/min max/;
use Term::ANSIColor;
use Algorithm::Diff qw/diff compact_diff/;

use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

has length => 0;
has shortest_note_time => 0;
has denominator => 4;
has beat_interval =>100000000;
has 'scores' => sub {return []}; # hash_ref
has 'notes' =>sub {return []}; # Model::Note
has midi_file  => '';
has note_file  => '';

has scale => 'c_dur';
# points:
has blueprint_file =>'';
has 'note_diff';
has beat_score => 0;
has note_score => 0;
has length_score =>0;
has delta_beat_score =>0;
has total_score => 0;
has startbeat => 0;
has debug => 0;
#has hand_left_max => 'H4';
#has hand_logic => 'static';
has 'allowed_note_lengths';
has 'allowed_note_types';
has ['hand_left_max','hand_right_min','hand_default'];
has 'comment';

=head1 NAME

Model::Tune - Handle tunes

=head1 SYNOPSIS

 use Model::Tune
 my $tune = Model::tune->from_notefile('my-notefile.txt');
 $tune->play;

=head1 DESCRIPTION

('note_off', dtime, channel, note, velocity)
('note_on',  dtime, channel, note, velocity)

=head1 METHODS

=head2 calc_length

Calculate length of song

=cut

sub calc_length {
    my $self = shift;
    my $last_note = $self->notes->[-1];
    return $last_note->startbeat->to_int + $last_note->length_numerator;
}

=head2 calc_shortest_note

Guess the shorest note. If shorter than 64 it is a 1/8 else 1/4.
Set denominator, beat_interval, beat_score,shortest_note_time

=cut

sub calc_shortest_note {
	my $self =shift;
	my $numnotes = $self->scores;
    if(! @$numnotes || @$numnotes == 1) {
#        warn Dumper \@$numnotes;
    	say "Zero or one note is not a tune.";

        return;
    }

	if(! exists $numnotes->[0]->{delta_time}) {
		say "Missing delta_time on notes";
	}

	my ($min_try,$max_try);
    $max_try = max grep{$_ && $_>=30} map{ $_->{delta_time} } @$numnotes;
    $min_try = min grep{$_ && $_>=10} map{ $_->{delta_time} } @$numnotes;

    my $try;
    if (!defined $min_try || ! defined $max_try) {
    	$try = 48;
    } else {
    	$try = int(($min_try+$max_try) / 2);
    }
	my $best = {period=>1000, value=>10000000};

#	my $new_try=$try-1;

	$numnotes = scalar @$numnotes;
	while ($try>15) {
        #$diff >= $self->_calc_time_diff($new_try) || $diff / $numnotes > 14
		my $diff= $self->_calc_time_diff($try);
        if ($diff/$try < $best->{'value'}) {
            $best = {value => $diff/$try, 'period'=>$try};
        }
		$try--;

	}
	$self->beat_interval($best->{'value'} * $best->{'period'});
	printf "# d:%s - nn:%s - dv:%2.2f - p:%d\n",$self->beat_interval, $numnotes, $best->{value} / $numnotes, $best->{'period'};
    my $tmp = ($best->{value} / $numnotes);
#    warn $tmp;
    $tmp *= 100;
#    warn $tmp;
    $tmp = 25 - $tmp;
#    warn $tmp;
    $tmp = $tmp*4;
#    warn $tmp;
    $self->beat_score( int ((25 -(100 * ($best->{value} / $numnotes)))*4 ));

	$self->shortest_note_time($best->{'period'});
    if ( $best->{'period'} >= 64 ) {
        $self->denominator(4);
    } elsif( $best->{'period'} < 64 ) {
        $self->denominator(8);
    }
	return $self;
}


=head2 clean

Modify tune after sertant rules like extend periods defined in opts argument.
Opts is a has ref, can have these options: extend, nobeattresspass, upgrade 0/1.

=cut

sub clean {

    my $self = shift;
    my $opts = shift;
    my $startbeat = Model::Beat->new(denominator=>$self->denominator);
    if ($opts) {
      my $extend;
      if ($opts->extend) {
        @$extend = split(/\,/,$opts->extend);
      }
      my @notes = @{ $self->notes };
      for my $note(@notes) {
        if (defined $extend) {
          for my $t(@$extend) {
            if ( $note->delta_place_numerator == $t )  {
              $note->delta_place_numerator($note->delta_place_numerator+1);
            }
            if ( $note->length_numerator == $t ) {
              $note->length_numerator($note->length_numerator+1);
              my ($ln,undef) = Model::Utils::calc_length({numerator => $note->length_numerator}
              ,,{shortest_note_time=>$self->shortest_note_time, denominator=>$self->denominator});
              $note->length_name($ln);
            }
          }

        }
        $startbeat = $startbeat + $note->delta_place_numerator;
        $note->startbeat($startbeat->clone);
      }
      $self->notes(\@notes);
    }

    return $self;
}

=head2 evaluate_with_blueprint

Compare notes with notes.
Self is the played tune in note format and the argument is a Model::Tune which is the blueprint.
This method should give an over all score and partly socres for corerect played notes, correct beat, correct note length++.
And the diff between the blueprint and the played should show what should be played better to get an higher score.

Return by default a text - evaluation. With options {output=>hash} this method will return an hash ref with data from the evaluation.

=cut

sub evaluate_with_blueprint {
	my $self = shift;
	my $blueprint = shift;
	my $options = shift;
    $self->blueprint_file($blueprint->note_file);
	my $result={};
	my @played_note_values = map{$_->note+0} @{ $self->notes};
	my @blueprint_note_values = map{$_->note + 0} @{ $blueprint->notes};
	my $diff = diff( \@played_note_values, \@blueprint_note_values );
    say "Sammenligne innput note" if $self->debug;
    say "Spilt:              ".join(',',map{Model::Utils::Scale::value2notename($self->{scale},$_)} @played_note_values ) if $self->debug;
    say "Fasit:              ".join(',',map{Model::Utils::Scale::value2notename($self->{scale},$_)} @blueprint_note_values ) if $self->debug;
	# remove first array_ref layer from diff
	my $wrongs=[];
	if (@$diff) {
		for my $area(@$diff){
			push @$wrongs, @$area;
		}
	}
#	say "171\n".Dumper $wrongs;
	# Calculate a note score
	my $n = ((scalar @{ $blueprint->notes } - scalar @$wrongs * 3)/(scalar @{ $blueprint->notes }))*100;
   warn $self->note_score($n);


	# Calculate a note map
    my %map;

	my $cdiff = compact_diff(\@played_note_values, \@blueprint_note_values);
    if ($self->debug) {
    	for ( my $i = 0;$i < $#{$cdiff}-2; $i += 4) {
    		printf "%d,%d;%d,%d\n",$cdiff->[$i],$cdiff->[$i+1],$cdiff->[$i+2],$cdiff->[$i+3];
    	}
    }

	for ( my $i = 0;$i < $#{$cdiff}-2; $i += 4) {
		if ($cdiff->[$i] == $cdiff->[$i+2]) {
            next;
        }
		for my $j(0 .. ($cdiff->[$i+2] - $cdiff->[$i] -1)){
			$map{$cdiff->[$i]+$j} = $cdiff->[$i+1]+$j;
		}

	}

	my $rln=0;# right length numerator
    my $rdb=0;# right delta beat
	for my $key(keys %map) {
		$rln++ if $self->notes->[$key]->length_numerator
            == $blueprint->notes->[$map{$key}]->length_numerator;
		$rdb++ if $self->notes->[$key]->delta_place_numerator
            == $blueprint->notes->[$map{$key}]->delta_place_numerator;
	}
	$self->length_score(    100*$rln/scalar @{ $blueprint->notes });
	$self->delta_beat_score(100*$rdb/scalar @{ $blueprint->notes });

	# Calculate dalta_note_beat score
	say '';

	# create array for print. Each entry has [diff_code,midi_note_place,blueprint_note_place]
	my $i=0;
	my $j=0;
	my @note_diff;
	my @maps = map { $_, $map{$_} } sort {$a <=> $b} keys %map;
    if ($self->debug) {
        for ( my $i = 0;$i < $#maps-2; $i += 2) {
            printf "mapping: %s,%s\n", $maps[$i],$maps[$i+1]
        }
    }

	while ( my ($m,$b) = (shift(@maps),shift(@maps) )) { #$m=blueprint,$b = played
		last if ! defined $m && ! defined $b;
		if ( $i < $m && $j < $b ) {
			while( $i < $m && $j < $b ) {
				print "$i,$j $m,$b\n";
				push @note_diff, ['1',$i,$j];
				$i++;$j++;
			}
		} elsif ( $i == $m && $j < $b ) {
			while( $i == $m && $j < $b ) {
				push @note_diff, ['2',undef,$j];
				$j++;
			}
		} elsif ( $i < $m && $j == $b ) {
			while( $i < $m && $j == $b ) {
				push @note_diff, ['3',$i,undef];
				$i++;
			}
		}

		if ($i == $m && $j == $b) {
			push @note_diff, ['100',$i,$j];
		}

        $i++;$j++;
	}
	#Register errous notes at the end.
	if ($i != $#{$self->notes} || $j != $#{$blueprint->notes}) {
		printf "%d=%d %d=%d\n",$i,$#{$self->notes},$j,$#{$blueprint->notes};
        $i = undef if $i>$#{$self->notes};
        $j = undef if defined $i && $i>$#{$blueprint->notes};
        push @note_diff,['4',$i,$j];
		while ($#{$self->notes} > ($i//$#{$self->notes}) || $#{$blueprint->notes} > ($j//$#{$blueprint->notes})){
            $i++ if defined $i; # && $#{$self->notes} >$i;
            $j++ if defined $j; # && $#{$blueprint->notes} >$j;
            push @note_diff,['4',$i,$j];
        }
	}
    for my $n (@note_diff) {
        next if $n->[0]<50;
        $n->[0] -= 19 if $self->notes->[$n->[1]]->length_numerator ne $blueprint->notes->[$n->[2]]->length_numerator;
        $n->[0] -= 35 if $self->notes->[$n->[1]]->delta_place_numerator ne $blueprint->notes->[$n->[2]]->delta_place_numerator;
    }
    $self->note_diff(\@note_diff);
    my $format = "%5s %-15s %s\n";
    say '';
    print color('blue');
    printf $format,"Poeng","Spilt", "Fasit";
    printf $format,"-----",'-----------','-----------';
	for my $n(@note_diff) {
		if (defined $n->[1] && defined $n->[2]) {
			if ($n->[0] > 90) {
				print color('green');
			} elsif ($n->[0] > 45) {
				print color('yellow');
			} else {
                print color('red');
            }
			printf $format, $n->[0],defined $self->notes->[$n->[1]]? $self->notes->[$n->[1]]->to_string( {no_comment=>1, scale=>$blueprint->scale}) :''
			, defined $blueprint->notes->[$n->[2]] ? $blueprint->notes->[$n->[2]]->to_string({scale=>$blueprint->scale}) : '';
		}
		elsif (! defined $n->[1] && defined $n->[2]) {
			print color('red');
            if (defined $blueprint->notes->[$n->[2]]) {
                printf $format,$n->[0],''
					, $blueprint->notes->[$n->[2]]->to_string({scale=>$blueprint->scale});
            }
		}
		elsif (! defined $n->[2] && defined $n->[1]) {
			print color('red');
			printf $format,$n->[0],$self->notes->[$n->[1]]->to_string( {no_comment=>1, scale=>$blueprint->scale} )
						,'';
		}
		else {
			...;
		}
		print color('reset');
	}
    say '';
    printf "%-16s %3d\n",     "Played length:",	   $self->calc_length;
    printf "%-16s %3d\n",     "Blueprint length:", $blueprint->calc_length;
	printf "%-16s %3.1f%%\n", "Beat score:",	   $self->beat_score;
	printf "%-16s %3.1f%%\n", "Note score:",       $self->note_score;
	printf "%-16s %3.1f%%\n", "Length score:",     $self->length_score;
	printf "%-16s %3.1f%%\n", "Delta beat score:", $self->delta_beat_score;
	printf "%-16s %3.1f%%\n", "Total score:", (3 * $self->note_score + $self->length_score + $self->delta_beat_score + 2 * $self->delta_beat_score)/7;
	return $self;
}

=head2 find_best_scale

Return best fit scale for tune.

=cut

sub find_best_scale {
    my($self) = @_;
    my $return='c_dur';
    my %notemap;
    for my $n(@{$self->notes}) {
        $notemap{$n->note}++;
    }
    return $return;
}

=head2 from_midi_score


Take an array_ref of (MIDI) score and return a new Model::Tune object
Do not concatinate on beat yet.

=cut

sub from_midi_score {
    my $class = shift;
    my $score = shift;
    my $options =shift;
    die '\$score must be a array ref' if ! ref $score eq 'ARRAY' ;
    my $tune_start;

    # Order score_notes on starttime
    my $self = $class->new(%$options);
    my @score_t = sort {$a->[1] <=> $b->[1]} @$score;
    my @score;
    for my $sp(@score_t) {#0=type,1=dtime,2=duration,3=0,4=note,5=volumne
        next if $sp->[0] ne 'note';
        $tune_start=$sp->[1] if ! defined $tune_start;
        push @score, {starttime => $sp->[1] - $tune_start
        , duration => $sp->[2],channel =>$sp->[3], note =>$sp->[4], velocity =>$sp->[5]};

    }
        # warn Dumper \@notes;
    #@notes = sort { $a->{'starttime'} <=> $b->{'starttime'} }  @notes;


    my $pre_time;
    for my $note (@score) {
        if (! defined $pre_time) {
            # firt note in tune
            $pre_time = $note->{starttime};
            $note->{delta_time} = 0;
        } else {
            $note->{delta_time} = ($note->{starttime} - $pre_time);
            $pre_time = $note->{starttime};
        }
        push @{$self->scores}, $note;
    }
    # warn Dumper $self->notes;
    return $self;

}



=head2 from_midi_file

Take midifilename read it. Create a new Model::Tune object. Populate notes
 with score data(starttime,duration,note,velocity)

=cut


sub from_midi_file {
    my $class = shift;
    my $midi_filename = shift;
    die "\$midi_filename is not defined" if ! defined $midi_filename;
    die "The file $midi_filename does not exists." if ! -e $midi_filename;
    my $opus = MIDI::Opus->new({ 'from_file' => $midi_filename, 'no_parse' => 1 });#
    my @tracks = $opus->tracks;
    # print $self->file . " has ", scalar( @tracks ). " tracks\n";
    my $data = $tracks[0]->data;
    my $events = MIDI::Event::decode( \$data );
    my $score = MIDI::Score::events_r_to_score_r( $events );
    return $class->from_midi_score($score, { midi_file => $midi_filename, hand_split_on => 56 } );

}

=head2 from_note_file

Create a new Model::Tune object baset on note file.
Notes is registered with notefile data like (numerator,delta_place_numerator
, length_numerator, length_name, note_name, denominator)
Dies if not file is set.

=cut

sub from_note_file {
    my $class = shift;
    my $self = $class->new(note_file => shift);
    die "note_file is not set" if ! $self->note_file;
    die "Cant be midi file" if $self->note_file =~/.midi?$/i;
    my $path = path( $self->note_file );
    if (!-e $path) {
        warn "Unknown file ".$path->to_abs;
    }

    # remove old comments
    my $content = $path->slurp;
    my $newcont='';
    my %input;
    my @notes = ();

    #scan for variables
    for my $line (split/\n/,$content) {
        if ($line=~/([\w\_\-]+)\s*=\s*(.+)$/) {
            my ($key,$value) = ($1,$2);
            if ($key =~/s$/ ) {
                my $tmp = [split /\s*\,\s*/,$value];
                $self->$key($tmp);
            } else {
                $self->$key($value);
            }
        }
    }
    my $beat = Model::Beat->new(integer => $self->startbeat, denominator => $self->denominator);

    #read notes
    #warn "#".$beat;
    # Remove comments and add new
    for my $line (split/\n/,$content) {
        $line =~ s/\s*\#.*$//;
        last if $line eq '__END__';
        next if ! $line;
        if ($line=~/([\w\_\-]+)\s*=\s*(.+)$/) {
            next
        } else {
            my ($delta_place_numerator, $length_numerator, $note_name) = split(/\;/,$line);
            $beat = $beat + $delta_place_numerator;
            my ($ln,undef) = Model::Utils::calc_length({numerator =>$length_numerator}
            ,{shortest_note_time=>$self->shortest_note_time, denominator=>$self->denominator});
            push(@notes,Model::Note->new(delta_place_numerator => $delta_place_numerator,
            length_numerator => $length_numerator,
            length_name => $ln,
            note_name => $note_name,
            denominator => $self->denominator,
            startbeat =>$beat->clone,
            )->compile);
        }
    }

    @notes = grep { defined $_ } @notes;
    die"No notes $path" if ! @notes;
    $self->notes(\@notes);
    return $self;
}

=head2 get_beat_sum

Sum beat sum of a tune

=cut

sub get_beat_sum {
	my $self=shift;
	die "No notes" if ! @{$self->notes};
    my $return = 0;
    $return += $_ for map{$_->delta_place_numerator} @{$self->notes};
	#my $end_note = $self->notes->[-1]->length_numerator;
	#my $endbeat =$end_note->startbeat+$end_note->length_numerator;
    $return = $return/scalar @{$self->notes};
    return $return;
}

=head2 get_enriched_notes

Return al notes enriched with hand (left/right)

TODO:

=cut

sub get_enriched_notes {
	my $self = shift;
	my $return=[];
	@$return = map{ $_->to_hash } @{ $self->notes };
	...; # TODO enrich with hand
	return $return;
}

=head2 get_num_of_beats

Count number of beats.

=cut

sub get_num_of_beats {
	my $self = shift;
  my $lastnote = @{$self->notes}[-1];
  return $lastnote->startbeat->to_int + $lastnote->duration;
}

=head2 notes2score

Generate score data from notefile data.
Notefile data is: startbeat, length_numerator
score data is: 'note', starttime, duration, channel, note, velocity

=cut

sub notes2score {
	my $self = shift;
    my @notes = @ { $self->notes };

    # generate a temporary MIDI
    #(startbeat,length_numerator) => (starttime, duration)
    my @scores;
    my $prev_stime=0;
    for my $note (@notes) {
        my $score ={};
	    my $num = $note->startbeat->to_int;
# warn $num." * ".$self->shortest_note_time ;

        $score->{starttime} = $note->startbeat->to_int * $self->shortest_note_time; #or shortest_note_time?
        $score->{duration} = ($note->length_numerator * $self->shortest_note_time - 5); #or shortest_note_time?
        $score->{delta_time} = $score->{starttime} - $prev_stime;
        $score->{velocity}=96; #hardcoded for now
        $prev_stime = $score->{starttime};
        $score->{note} = $note->note;
        push(@scores, $score);
    }
    $self->scores(\@scores);
	return $self;
}

=head2 score2notes

Populate and change order for notes. Keep score as is.
and guess scale.

Contatinate beats.

Prepare output at notefile.
i.e
 denominator:4
 0.0;0.1;C4
 0.1;0.1;D4
...

Reseason for clone is to evaluate and see if right shortest_note is choosen outside of this sub or try again with different shortest_note with out adjusting order.

=cut

sub score2notes {
    my $self = shift;
    die "Missing denominator" if !$self->denominator;

    my @notes;
    my $startbeat = Model::Beat->new(denominator=>$self->denominator);
    my $prev_starttime=0;
    for my $score(@{$self->scores}) {
        my $note= Model::Note->new;
        my ($length_name, $length_numerator) = Model::Utils::calc_length( { time => $score->{duration} }
            ,{shortest_note_time=>$self->shortest_note_time, denominator=>$self->denominator} );
        $note->length_name($length_name);
        $note->length_numerator($length_numerator);
        #step up beat
        my $numerator = int( 0.5 + ($score->{delta_time} +0.0) / ($self->shortest_note_time+0.0) );

        die "MINUS" if $numerator<0;
        $startbeat = $startbeat + $numerator;
        $note->startbeat($startbeat->clone);
        $note->note($score->{note});
        #$note->order($note->startbeat->to_int*1000 + 128 - $note->note);
        printf "%6d %3d %3d %3s\n" ,$note->order,$startbeat->to_int,$score->{duration},Model::Utils::Scale::value2notename($self->{scale}//'c_dur',$note->note);# if $self->debug;
        push @notes,$note;
    }

    #sort notes
    my @onotes = sort {$a->order <=> $b->order} @notes;


    #loop another time through notes to calc delta_place_numerator after notes is sorted.
    my $prev_note_int = 0;#Model::Note->new(startbeat=>Model::Beat->new(number=>0, numerator=>0));
    for my $note(@onotes) {
		my $tb = $note->startbeat->to_int - $prev_note_int;#->startbeat->to_int;
		$note->delta_place_numerator($tb);
		$prev_note_int = $note->startbeat->to_int;
    }

    say "score2notes  2:      ".join(',',map {Model::Utils::Scale::value2notename($self->{scale},$_->note)} @onotes) if $self->debug;

    $self->notes(\@onotes);
    $self->scale(Model::Utils::Scale::guess_scale_from_notes($self->notes));
    return $self;
}

=head2 to_data_split_hands

Return a data object.

$data->{left}[0][0]

my ($data,$num_of_beats,$beat_size) = $tune->to_data_split_hands();

attributes for this function is

=over 4

=item hand_left_max i.e. H4

=item hand_right_min i.e C5

=item hand_default - Set to this if uncertain

=back

=cut

sub to_data_split_hands {
	my $self = shift;
	my $return={left=>[],right=>[],unknown=>[]};

    my ($max_left, $min_right);
    $max_left  = Model::Utils::Scale::notename2value($self->hand_left_max ) if $self->hand_left_max;
    $min_right = Model::Utils::Scale::notename2value($self->hand_right_min) if $self->hand_right_min;
    if ($max_left && ! $min_right) {
        $min_right = $max_left +1;
    } elsif (! $max_left && $min_right) {
        $max_left = $min_right - 1;
    } elsif (! $max_left && ! $min_right) {
        $max_left = 55;
        $min_right = $max_left + 1;
    } elsif ($max_left - $min_right > -1) {
        my ($tmp_left,$tmp_right) = ( $max_left, $min_right );
        $max_left = $tmp_right - 1;
        $min_right = $tmp_left + 1;
    }
    # warn "hands $max_left $min_right";
	for my $i(0 .. $#{ $self->notes }) {
        my $note = $self->notes->[$i];
	       # code for split left and right
	       # split
	       # look back to se if ok
        my $hash = $note->to_hash_ref;
        if ($hash->{note} == -1 ) {
	   		push @{ $return->{'left'} }, $note;
        } elsif ( $hash->{note} == -2) {
   	  		push @{ $return->{'right'} }, $note;
		} elsif ($hash->{note} >= $min_right) {#	 right
	    	push @{ $return->{'right'} }, $note;
	   	} elsif($hash->{note} <= $max_left) { # left
	      	push @{ $return->{'left'} }, $note;
        } else {
            # Algorithm
            my $p = $self->notes->[$i-1];
            my $n = $self->notes->[$i+1] ;
            if (($p->note==-2 || $p->note>= $min_right) && $note->delta_place_numerator == 0) {
                # right hand puse on same beat place.
                push @{ $return->{'left'} }, $note;

            }
            elsif (defined $n && ($n->note==-1 || $n->note<=$max_left ) && $n->delta_place_numerator == 0) {
                # left hand pause on same beat place.
                push @{ $return->{'right'} }, $note;
            }
            elsif (scalar @{$return->{right}} && scalar @{$return->{left}}
                && $note->startbeat->to_int == $return->{right}->[-1]->startbeat->to_int
                + $return->{right}->[-1]->length_numerator
                && $note->startbeat->to_int != $return->{left}->[-1]->startbeat->to_int
                + $return->{left}->[-1]->length_numerator
                ) {
                    # right hand ready not left
                    push @{ $return->{'right'} }, $note;
            }# which hand plays similar length
            elsif (scalar @{$return->{left}} && scalar @{$return->{right}}
                && $note->startbeat->to_int == $return->{left}->[-1]->startbeat->to_int
                + $return->{left}->[-1]->length_numerator
                && $note->startbeat->to_int != $return->{right}->[-1]->startbeat->to_int
                + $return->{right}->[-1]->length_numerator
                ) {
                    # left hand ready not right
                    push @{ $return->{'left'} }, $note;
            }# which hand plays similar length
			elsif ($self->hand_default) {
	            # choose hand_default if set
	            die "default can either be left or right: ".$self->hand_default if $self->hand_default !~ 'left' && $self->hand_default !~ 'right';
	            push @{ $return->{$self->hand_default} }, $note;
	        } else {
	            # dies in end and ask for advice
	            say STDERR Dumper $hash;
	            if (scalar @{$return->{left}} && scalar @{$return->{right}} ) {
		            printf STDERR "%s  %s  %s", $i,$return->{left}->[-1]->startbeat->to_int
	                + $return->{left}->[-1]->length_numerator,
	                $return->{right}->[-1]->startbeat->to_int
	                + $return->{right}->[-1]->length_numerator ;
	            }
	            push @{ $return->{'unknown' }}, $note;
	  	  #          die "Tried all rules. Please have a look and give me an advice.";
            }
        }
    }
	return $return;
}

=head2 to_midi_file

Takes midi filename. If none use $class->midi_file instead.
Write midi file to disk based on score data (and not note data(must use note2score first)).

=cut

sub to_midi_file {
    my $self =shift;
    my $midi_file = shift;
    if (! $midi_file) {
        $midi_file = $self->midi_file;
    } else {
        $self->midi_file($midi_file);
    }

    my $file = path($midi_file);
    say $file;
    my $score_r=[];
    for my $score(@{$self->scores}) {
        # ('note', starttime, duration, channel, note, velocity)
        push @$score_r, ['note', $score->{starttime}, $score->{duration}, 0, $score->{note}, $score->{velocity}//96];
    }
    my $events_r = MIDI::Score::score_r_to_events_r( $score_r );

    # Put on defaults
	unshift @$events_r, ['set_tempo',0,500000], ['time_signature',0,4,2,24,8],
['patch_change',	1,	0,	0],
['pitch_wheel_change',	1,	0,	0],
['set_tempo',	327,	500000];

	my $one_track = MIDI::Track->new;
	$one_track->events_r( $events_r );
	my $opus = MIDI::Opus->new(
	 {  'format' => 1,  'ticks' =>120 # to slow :$self->shortest_note_time
     , 'tracks' => [ $one_track ] }	);
        die "Missing midi_file. Do not know what todo" if (! $midi_file);
    $opus->dump;
    print '['.join (', ',@$_)."]\n" for  $opus->tracks_r()->[0]->events;
	$opus->write_to_file($midi_file);
    return $self;
}

=head2 to_note_file

Write tune to note file

=cut

sub to_note_file {
    my $self =shift;
    my $note_file = shift;
    $note_file = $self->note_file if ! $note_file;
    my $file =  path($note_file);
    say $file;
    if (! $note_file) {
        say "Missing name SYNTAX: s <SONGNAME>";
        return $self;
    }

    my $content = $self->to_string({end=>"\n"});
    die "No content" if ! $content;
    $file->spurt($content);
    return $self;
}

=head2 to_string

Return a text with all notes and some general variables for the tune.

=cut


sub to_string {
	my $self = shift;
#	my $args = shift;

	my @notes;
	@notes = map{$_->to_string({scale => $self->{scale}, end =>"\n"})} grep {$_} @{$self->notes};
has 'allowed_note_lengths';
has 'allowed_note_types';
has ['hand_left_max','hand_right_min','hand_default'];

	my $return='';
    for my $name (qw/denominator shortest_note_time beat_score scale startbeat
    	allowed_note_lengths allowed_note_types hand_left_max hand_right_min hand_default
    	comment /) {

    	if ($self->$name ) {
    		my $value = $self->$name;
    		if (! ref $value) {
    			$return .=  sprintf "$name=%s\n", $self->$name;
    		} elsif ( ref $value eq 'ARRAY' ) {
    			$return .=  sprintf "$name=%s\n", join(',',@{ $self->$name });
    		} else {
    			die "no support for ". ref $value;
    		}
    	}
    }
  return $return . join('',@notes)."\n";
}

#
#   PRIVATE SUBS
#

sub _calc_time_diff {
	my $self = shift;

  my $try = shift||confess"Miss try";
	my $notes = $self->scores;
	my @notes = @$notes;
	my $return=0;
	for my $note(@notes) {
		my $i = 1;
		my $nd = $note->{delta_time};
		my $d1 = $nd;
		my $d2 = abs( $nd - $try);
		while ( $d1 > $d2 || $d1 > $try) {
		  $d1 = $d2;
			$d2 = abs( $nd - $try*$i );
            $i++;
		}
#        warn ":$i - nd:$nd - d1:$d1 - d2:$d2 - try:$try";
		$return += $d1;
	}
#	warn "$try - $return";
	return $return;
}


1;
