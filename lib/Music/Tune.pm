  package Music::Tune;
use Mojo::Base -base,-signatures;
use Music::Note;
use Music::Position;
use Music::Utils;
use Music::Utils::Scale;
use Data::Dumper;
use Mojo::JSON 'to_json';
use MIDI;
use Tie::IxHash;
use Clone 'clone';

use Carp;
use List::Util qw/min max/;
use Term::ANSIColor;
use Algorithm::Diff qw/diff compact_diff LCSidx/;
use Mojo::File qw(tempfile path);
use IO::Scalar;
use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

has length => 0;
has shortest_note_time => 0;
has denominator => 8;
has beat_interval =>100000000;
has 'scores' => sub {return []}; # hash_ref
has 'notes' =>sub {return []}; # Music::Note
has midi_file  => '';
has note_file  => '';
has name => '';
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
has 'allowed_note_lengths';
has 'allowed_note_types';
has ['hand_left_max','hand_right_min','hand_default'];
has 'comment';
has 'totaltime';
has in_midi_events => sub {[]}; # For storing input for later convertion

=head1 NAME

Music::Tune - Handle tunes

=head1 SYNOPSIS

 use Music::Tune;
 use Mojo::File 'path';
 my $content = path('my-notefile.txt')->slurp;
 my $tune = Music::Tune->from_string($content);
 $tune->play;

=head1 DESCRIPTION

('note_off', dtime, channel, note, velocity)
('note_on',  dtime, channel, note, velocity)

No file interaction. Consumer object is responsible for writing to disk.

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

Guess the shortest note. If shorter than 64 it is a 1/8 else 1/4.
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
    if ( $best->{'period'} >= 96 ) {
        $self->denominator(4);
    } elsif( $best->{'period'} < 96 ) {
        $self->denominator(8);
    }
	return $self;
}

=head2 get_best_shortest_note

Take played score.
Compare with tune and return best suited shortest note value

scoreformat:
('note', starttime, duration, channel, note, velocity)

Noteformat:
$note->note

=cut

sub get_best_shortest_note($self, $played_score) {
#    say STDERR Dumper $played_score;
    #die "Missi" if ! @$played_score;
# prepare diff
	my @played_note_values = map{$_->[4]} @{ $played_score};
	my @blueprint_note_values = map{$_->note + 0} @{ $self->notes};
	my( $idx1, $idx2 ) = LCSidx( \@played_note_values, \@blueprint_note_values );
	my @shortest_notes_time;
	if (scalar @$idx1< 4) {
	    say STDERR '$idx1';
#        warn Dumper $played_score;

        return 50; # some default value
	}

# calculate all the shortest_note for all relevant notes.
	for my $i (0 .. $#$idx1) {
        next if $idx1->[$i] == 0; # no previous note to calculated diff in time
        next if ! $self->notes->[$idx2->[$i]]->delta_place_numerator; # remove when length_numerator == 0
        my $delta_time = $played_score->[$idx1->[$i]]->[1] - $played_score->[$idx1->[$i] -1]->[1];
        next if $delta_time < 4;
        say "$i $played_score->[$idx1->[$i]] ".($played_score->[$idx1->[$i]]->[1]//'__UNDEF__')." : ".($played_score->[$idx2->[$i]]//'')." ".($self->notes->[$idx2->[$i]]->delta_place_numerator//'');
        push @shortest_notes_time, $delta_time / $self->notes->[$idx2->[$i]]->delta_place_numerator;  # duration/delta_place_numerator
	}

# Return median
    @shortest_notes_time = sort {$a <=> $b} @shortest_notes_time;
#    say Dumper \@shortest_notes_time;
    my $return;
    return 60 if ! scalar @shortest_notes_time;
    if (scalar $#shortest_notes_time %2 ==0 ) {
        $return =  $shortest_notes_time[$#shortest_notes_time/2];
    }
    else {
        $return = ($shortest_notes_time[int($#shortest_notes_time/2) +1 ] + $shortest_notes_time[int($#shortest_notes_time/2) ])/2;
    }
    return $return if $return;
    return 50;
}

=head2 clean

Modify tune after certain rules like extend periods defined in opts argument.
Opts is a has ref, can have these options: extend, nobeattresspass, upgrade 0/1.

=cut

sub clean {

    my $self = shift;
    my $opts = shift;
    my $count_first = $self->startbeat ? 0 :1;
    my $startbeat = Music::Position->new(denominator=>$self->denominator, count_first=>$count_first);
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
              my ($ln,undef) = Music::Utils::calc_length({numerator => $note->length_numerator}
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
Self is the played tune in note format and the argument is a Music::Tune which is the blueprint.
This method should give an over all score and partly scores for correct played notes, correct beat, correct note length++.
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
    say "Spilt:              ".join(',',map{Music::Utils::Scale::value2notename($self->{scale},$_)} @played_note_values ) if $self->debug;
    say "Fasit:              ".join(',',map{Music::Utils::Scale::value2notename($self->{scale},$_)} @blueprint_note_values ) if $self->debug;
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
	say STDERR "##### $n wrongs: ".scalar @$wrongs ."  ".scalar @{ $blueprint->notes }. " ### ".join("\n", map {join ';',@$_ } @$wrongs)  ;
    $self->note_score($n);


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

	# Calculate delta_note_beat score

	# create array for print. Each entry has [diff_code,midi_note_place,blueprint_note_place]
	my $i=0;
	my $j=0;
	my @note_diff;
	my @maps = map { $_, $map{$_} } sort {$a <=> $b} keys %map;
    if ($self->debug) {
        for ( my $i = 0;$i < $#maps-2; $i += 2) {
			say '';
            printf "mapping: %s,%s\n", $maps[$i],$maps[$i+1]
        }
    }

	while ( my ($m,$b) = (shift(@maps),shift(@maps) )) { #$m=blueprint,$b = played
		last if ! defined $m && ! defined $b;
		if ( $i < $m && $j < $b ) {
			while( $i < $m && $j < $b ) {
#				print "$i,$j $m,$b\n";
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
		} elsif ($i== $m && $j == $b) {
            # success

		} else{
				push @note_diff, ['4',$#maps,$#maps];
		}

		if ($i == $m && $j == $b) {
			push @note_diff, ['100',$i,$j];
		} else {
				push @note_diff, ['5',$i,$j];

		#    say "4 $i == $m && $j == $b";
#		    ...;
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
			printf $format, $n->[0],defined $self->notes->[$n->[1]]? $self->notes->[$n->[1]]->to_string( {no_comment=>1, scale=>$blueprint->scale, count_first => ($self->startbeat?0:1),}) :'X'
			, defined $blueprint->notes->[$n->[2]] ? $blueprint->notes->[$n->[2]]->to_string({scale=>$blueprint->scale,count_first => ($self->startbeat?0:1),}) : 'X';
		}
		elsif (! defined $n->[1] && defined $n->[2]) {
			print color('red');
            if (defined $blueprint->notes->[$n->[2]]) {
                printf $format,$n->[0],''
					, $blueprint->notes->[$n->[2]]->to_string({scale=>$blueprint->scale,count_first => ($self->startbeat?0:1),});
            }
		}
		elsif (! defined $n->[2] && defined $n->[1]) {
			print color('red');
			printf $format,$n->[0],$self->notes->[$n->[1]]->to_string( {no_comment=>1, scale=>$blueprint->scale,count_first => ($self->startbeat?0:1),} )
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
	my $tscore = (3 * $self->note_score + $self->length_score + $self->delta_beat_score + 2 * $self->delta_beat_score)/7;
	if ($tscore < -100) {
		$tscore = -100;
	}
	printf "%-16s %3.1f%%\n", "Total score:", $tscore;
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

=head2 finish

Make the tune ready (for comparing, saving etc)
Execute after tune actions.
After last played note is finished. End tune and look for blueprints to compare.

=cut

sub finish {
    my ($self) = @_;
    return $self if (@{$self->in_midi_events} <= 10);
    my $score = MIDI::Score::events_r_to_score_r( $self->in_midi_events );
    $self = Music::Tune->from_midi_score($score);

    $self->calc_shortest_note;
    $self->score2notes;

    printf "\n\nMusic::Tune->finish\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;

#    my $guess = $self->guessed_blueprint();
#    return $self if ! $guess;
#    print color('green');
#    say "Tippet låt: ". ($guess);
#    print color('reset');
#    $self->do_comp($guess);
    return $self;
}

=head2 from_data

    my $tune = Music::Tune->from_data({name=>'piano song',scale=>'c_dur'notes=>[]})

Take a deep datastructure and return a Music::Tune object

=cut

sub from_data($class,$data) {
    my $return = $class->new(%$data);
    return $return;
}

=head2 from_midi_score


Take an array_ref of (MIDI) score and return a new Music::Tune object
Do not concatenate on beat yet.

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
        if ($sp->[0] ne 'note' && $sp->[0] ne 'control_change') {
            next;
        }
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

Take midifilename read it. Create a new Music::Tune object. Populate notes
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
    return $class->from_midi_score($score, { midi_file => $midi_filename, hand_right_min => 'C4' } );

}

=head2 from_string

    my $tune = Music::Tune->from($text,{ignore_end=>1});

Input is the content of at note file, either from local disk or external api. First parameter is the text to be parsed. The second is options as a hash ref.

ignore_end=>1 means read the hole text and ignore words like __START__, __END__, __LEFT__, __RIGHT__

=cut


sub from_string {
    my $class = shift;
    my $content = shift or die "Missing content";
    my $options = shift;
    my $self = $class->new;

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
    my $count_first = $self->startbeat ? 0 :1;
    my $beat = Music::Position->new(integer => $self->startbeat, denominator => $self->denominator, count_first=>$count_first);

    my @hands;
    my $hand;
    for my $line (split/\n/,$content) {
        $line =~ s/\s*\#.*$//;
        if ($line eq '__START__') {
            if($options->{ignore_end}) {
                push(@notes,Music::Note->new(type=>'string', string=>'__START__', startbeat=>$beat->clone));
            } else {
                @notes=(); #remove previous registered notes
            }
            next;
        } elsif ($line eq '__END__') {
            if($options->{ignore_end}) {
                push(@notes,Music::Note->new(type=>'string',string=>'__END__', startbeat=>$beat->clone));
                next;
            } else {
                last;
            }
        } elsif ($line eq '__LEFT__') {
            if($options->{ignore_end}) {
                push(@notes,Music::Note->new(type=>'string',string=>'__LEFT__', startbeat=>$beat->clone));
                next;
            } else {
                $hand = 'left';
            }
            next;
        } elsif ($line eq '__RIGHT__') {
            if($options->{ignore_end}) {
                push(@notes,Music::Note->new(type=>'string',string=>'__RIGHT__', startbeat=>$beat->clone));
                next;
            } else {
                $hand = 'right';
            }
            next;
        } elsif ($line eq '__BOTH__') {
            if($options->{ignore_end}) {
                push(@notes,Music::Note->new(type=>'string',string=>'__BOTH__', startbeat=>$beat->clone));
                next;
            } else {
                $hand = undef;
            }
            next;
        }

        next if ! $line;
        if ($line=~/([\w\_\-]+)\s*=\s*(.+)$/) {
            next;
        } else {
            push @hands, $hand;
            my ($delta_place_numerator, $length_numerator, $note_name) = split(/\;/,$line);
            $beat = $beat + $delta_place_numerator;
            my $count_first = ( $self->startbeat ? 0 : 1 );
            my ($ln,undef) = Music::Utils::calc_length({numerator =>$length_numerator}
            ,{shortest_note_time=>$self->shortest_note_time, denominator=>$self->denominator});
            push(@notes,Music::Note->new(delta_place_numerator => $delta_place_numerator,
            length_numerator => $length_numerator,
            length_name => $ln,
            note_name => $note_name,
            denominator => $self->denominator,
            startbeat =>$beat->clone,
            count_first => $count_first,
            type => ($note_name =~/[A-H][\w\-]*\d$/ ? 'note': $note_name)
            )->compile);
        }
    }

    @notes = grep { defined $_ } @notes;
    $self->notes(\@notes);

    # Remove unwanted notes

    my $garbage = $self->to_data_split_hands;

    if ( ! $options->{ignore_end} ) {
        my @notesx;
        for my $x(0 .. $#hands) {
            if (! $hands[$x]) {
                push @notesx, $notes[$x];
            } elsif( $hands[$x] eq 'right' && $notes[$x]->hand ne 'left') {
                push @notesx, $notes[$x];
            } elsif( $hands[$x] eq 'left' && $notes[$x]->hand ne 'right') {
                push @notesx, $notes[$x];
            }
        }
        $self->notes(\@notesx);
    }
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

=head2 per_minute

    say $tune->per_minute;

Return per_minute value based on shortest_note_time

=cut

sub per_minute($self) {
    return 60 * 100 / $self->shortest_note_time * $self->denominator /4
}

=head2 play

Takes self, filepathname
Plays self->tune or given filepathname

=cut

sub play {
    my $tmpfile = tempfile(DIR=>'/tmp');
    $tmpfile->spew($_[0]->to_midi_file_content("$tmpfile"));
    print `timidity $tmpfile`;
}



=head2 score2notes

Populate and change order for notes. Keep score as is.
and guess scale.

Concatenate beats.

Prepare output at notefile.
i.e
 denominator:4
 0.0;0.1;C4
 0.1;0.1;D4
...

Reason for clone is to evaluate and see if right shortest_note is chosen outside of this sub or try again with different shortest_note with out adjusting order.

=cut

sub score2notes {
    my $self = shift;
    die "Missing denominator" if !$self->denominator;

    my @notes;
    my $count_first = $self->startbeat ? 0 :1;
    my $startbeat = Music::Position->new(denominator=>$self->denominator, count_first=>$count_first);
    my $prev_starttime=0;
    $self->totaltime(0);
    for my $score(@{$self->scores}) {
        my $note= Music::Note->new(count_first => ($self->startbeat?0:1),);
        $self->totaltime($self->totaltime + $score->{duration});
        my ($length_name, $length_numerator) = Music::Utils::calc_length( { time => $score->{duration} }
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
        printf "%6d %3d %3d %3s\n" ,$note->order,$startbeat->to_int,$score->{duration},Music::Utils::Scale::value2notename($self->{scale}//'c_dur',$note->note) if $self->debug;
        push @notes,$note;
    }

    #sort notes
    my @onotes = sort {$a->order <=> $b->order} @notes;


    #loop another time through notes to calc delta_place_numerator after notes is sorted.
    my $prev_note_int = 0;#Music::Note->new(startbeat=>Music::Position->new(number=>0, numerator=>0));
    for my $note(@onotes) {
		my $tb = $note->startbeat->to_int - $prev_note_int;#->startbeat->to_int;
		$note->delta_place_numerator($tb);
		$prev_note_int = $note->startbeat->to_int;
    }

    say "score2notes  2:      ".join(',',map {Music::Utils::Scale::value2notename($self->{scale},$_->note)} @onotes) if $self->debug;

    $self->notes(\@onotes);
    $self->scale(Music::Utils::Scale::guess_scale_from_notes($self->notes));
    return $self;
}

=head2 to_data

Return a complete hash datastructure reference.
Made for use with SH::DataStructure.

Notes is stored as /notes/[0..$#]

Return Music::Tune->new()->attr

Delete some uninteresting attributes like filename and score

=cut

sub to_data($self) {
    my $return = {};
    for my $k(keys %$self) {
        next if grep {$k eq $_} qw/scores midi_file note_file blueprint_file note_diff beat_score note_score length_score delta_beat_score total_score in_midi_events/;
        $return->{$k} = $self->$k;
    }
    return $return;
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
    $max_left  = Music::Utils::Scale::notename2value($self->hand_left_max ) if $self->hand_left_max;
    $min_right = Music::Utils::Scale::notename2value($self->hand_right_min) if $self->hand_right_min;
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
        if (exists $hash->{type} && $hash->{type} ne 'note') {
            if ($hash->{note} eq 'PL') {
                $note->{hand}= 'left';
    	   		push @{ $return->{'left'} }, $note;
            } elsif ($hash->{type} eq 'PR') {
                $note->{hand}= 'right';
    	   		push @{ $return->{'right'} }, $note;
            } elsif ($hash->{type} eq 'PD') {
                $note->{hand}= 'fot';
    	   		push @{ $return->{'fot'} }, $note;
            } else {
#                warn Dumper $hash;
                $note->{hand}= 'fot';
    	   		push @{ $return->{'fot'} }, $note;
            }
        }
        elsif ($hash->{note} == -1 ) {
            $note->{hand}= 'left';
	   		push @{ $return->{'left'} }, $note;
        } elsif ( $hash->{note} == -2) {
            $note->{hand}= 'right';
   	  		push @{ $return->{'right'} }, $note;
		} elsif ($hash->{note} >= $min_right) {#	 right
            $note->{hand}= 'right';
	    	push @{ $return->{'right'} }, $note;
	   	} elsif($hash->{note} <= $max_left) { # left
            $note->{hand}= 'left';
	      	push @{ $return->{'left'} }, $note;
        } else {
            # Algorithm
            my $p = $self->notes->[$i-1];
            my $n = $self->notes->[$i+1] ;
            if (($p->note==-2 || $p->note>= $min_right) && $note->delta_place_numerator == 0) {
                # right hand puse on same beat place.
                $note->{hand}= 'left';
                push @{ $return->{'left'} }, $note;

            }
            elsif (defined $n && ($n->note==-1 || $n->note<=$max_left ) && $n->delta_place_numerator == 0) {
                # left hand pause on same beat place.
                $note->{hand}= 'right';
                push @{ $return->{'right'} }, $note;
            }
            elsif (scalar @{$return->{right}} && scalar @{$return->{left}}
                && $note->startbeat->to_int == $return->{right}->[-1]->startbeat->to_int
                + $return->{right}->[-1]->length_numerator
                && $note->startbeat->to_int != $return->{left}->[-1]->startbeat->to_int
                + $return->{left}->[-1]->length_numerator
                ) {
                    # right hand ready not left
                    $note->{hand}= 'right';
                    push @{ $return->{'right'} }, $note;
            }# which hand plays similar length
            elsif (scalar @{$return->{left}} && scalar @{$return->{right}}
                && $note->startbeat->to_int == $return->{left}->[-1]->startbeat->to_int
                + $return->{left}->[-1]->length_numerator
                && $note->startbeat->to_int != $return->{right}->[-1]->startbeat->to_int
                + $return->{right}->[-1]->length_numerator
                ) {
                    # left hand ready not right
                    $note->{hand}= 'left';
                    push @{ $return->{'left'} }, $note;
            }# which hand plays similar length
			elsif ($self->hand_default) {
	            # choose hand_default if set
	            die "default can either be left or right: ".$self->hand_default if $self->hand_default !~ 'left' && $self->hand_default !~ 'right';
	            push @{ $return->{$self->hand_default} }, $note;
	        } else {
	            # dies in end and ask for advice
#	            say STDERR Dumper $hash;
	            if (0 && scalar @{$return->{left}} && scalar @{$return->{right}} ) {
		            warn sprintf "%s  %s  %s", $i,$return->{left}->[-1]->startbeat->to_int
	                + $return->{left}->[-1]->length_numerator,
	                $return->{right}->[-1]->startbeat->to_int
	                + $return->{right}->[-1]->length_numerator ;
	            }
                $note->{hand}= 'unknown';
	            push @{ $return->{'unknown' }}, $note;
	  	  #          die "Tried all rules. Please have a look and give me an advice.";
            }
        }
    }
	return $return;
}

=head2 to_midi_file_content

Takes midi filename. If none use $class->midi_file instead.
Write midi file to disk based on score data (and not note data(must use note2score first)).

=cut

sub to_midi_file_content {
    my $self =shift;
    # my $midi_file = shift;
    # if (! $midi_file) {
    #     $midi_file = $self->midi_file;
    # } else {
    #     $self->midi_file($midi_file);
    # }
    #
    # my $file = path($midi_file);
#    say $file;
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
#        die "Missing midi_file. Do not know what todo" if (! $midi_file);
    $opus->dump;
    print '['.join (', ',@$_)."]\n" for  $opus->tracks_r()->[0]->events;
    my $data;
    my $SH = IO::Scalar->new(\$data);
	$opus->write_to_handle($SH );
    return $data;
    #return $self;
}

=head2 to_midi_events

Return tune as MIDI::Events

=cut

sub to_midi_events($self) {
        $DB::single=2;

    if (@{ $self->in_midi_events }) {
            return  $self->in_midi_events ;
    }
    if (!@{ $self->scores }) {
        $self->notes2score;
    }

    if (@{ $self->scores }) {
        my $scores = $self->scores;

        # convert to midi scores
#        {starttime, duration, delta_time, velocity,note}
        # from hash {starttime, duration, delta_time, velocity,note} to:('note', starttime, duration, channel, note, velocity)
        my $events=[];
        for my $s(@$scores) {
            push @$events,['note',$s->{starttime}, $s->{duration},0,$s->{note},$s->{velocity}];

        }

        MIDI::Score::score_r_to_events_r( $events );
        return $events;
    }
    else {
        warn "EMPTY RESULT";
        return;
    }
}

=head2 to_midi_score

Return tune as MIDI::Score

scoreformat:
('note', starttime, duration, channel, note, velocity)


=cut

sub to_midi_score($self) {
    if (@{ $self->in_midi_events }) {
        return  MIDI::Score::events_r_to_score_r( $self->in_midi_events );
    }
    else {
        if (! @{ $self->scores }) {
           return [] if ! @{ $self->notes };
            $self->notes2score;
        }
        my $return=[];
        for my $score (@{ $self->scores }) {
            push @$return, ['note', $score->{starttime}, $score->{duration}, 0, $score->{note}, $score->{velocity}//96];
        }
        return $return;
    }
    # else {
        # die 'Impossible with out $self->shortest_note_time' if !$self->shortest_note_time;
        # my $snt = $self->shortest_note_time;
        # my $time=0;
        # my @score;
        # for my $note (@{ $self->notes }) {
            # push @score,['note',$time + $note->delta_place_numerator * $snt,$note->length_numerator * $snt,0, ];
        # }
        # warn "... Make notes to scores";
# #        ...;
        #
    # }
}

=head2 xml

Utility function to generate XML as text.

    $xml =  xml('key',{parameter=>''},$value);
    $xml .= xml('key2','value2');

=cut

sub xml {
    my $key = shift ||die "no key";
    my $hash;
    if (ref $_[0] eq 'HASH') {
        $hash =shift;
    }
    my $text;
    $text = shift if defined $_[0] && length($_[0]);
    my $return='';
    if (! $hash) {
        $return .= "<$key>";
    } else {
        $return .= "<$key";
        while (my ($k,$v) = each %$hash) {
            $return .= " $k=\"$v\"";
        }
        $return .=">";
    }
    $return .= "\n" if $text && $text =~/\>/;
    $return .= $text if length($text);
    $return .= "</$key>";
    $return .= "\n";# if $text && $text =~/\>/;
    return $return;
}

=head2 xml_measure

    my $xml= xml_measure($hashxml);

Takes a hash with measure data and produce xml-text.

=cut

sub xml_measure {
    my $measure = shift;
    die if ! $measure->{denominator};
    return xml('measure', {'number' => $measure->{number}}
        ,join('', $measure->{attributes},
        ,map {xml('note',
            ($_->{chord}?xml('chord',''):'')
            . ($_->{rest}?xml('rest',''):
             xml('pitch', xml('octave', $_->{octave}) . xml('step', $_->{step})
              . (exists $_->{alter} && $_->{alter}?xml('alter', $_->{alter}):'')
             )
            )
             . xml('duration', $_->{duration} )
             . xml('type', $_->{type} )
             . (exists $_->{dot} && $_->{dot}? xml('dot','') : '')
            . xml('staff', 1)
        )} @{$measure->{right}->{notes}} )
        .  xml('backup', xml('duration', $measure->{denominator}))
        . join('',
         map {xml('note',
            ($_->{chord}?xml('chord',''):'')
            . ($_->{rest}?xml('rest',''):
             xml('pitch', xml('octave', $_->{octave}) . xml('step', $_->{step}).
              (exists $_->{alter} && $_{alter}?xml('alter', $_->{alter}):'')
             )
            )
            . xml('duration', $_->{duration} )
            . xml('type', $_->{type} )
            . (exists $_->{dot} && $_->{dot}? xml('dot','') : '')
            . xml('staff', 2)
        )} @{$measure->{left}->{notes}} )

    )

}


=head2 to_musicxml_text

Return a long string on MusicXML format

=cut

sub to_musicxml_text($self){
    my @measures=();
    my $tick = $self->startbeat;
    my $measure_number = 1;
    if ($self->startbeat) {
        $tick = $self->startbeat;
        $measure_number = 0;
    }
    $self->to_data_split_hands; # as a beeffect set hand
    die if ! @{ $self->notes };
    my $measure = {
        number => $measure_number,
        denominator => $self->denominator,
        attributes => xml('attributes'
                    ,xml('divisions','2' ).
                    xml('key',xml('fifths','0')).
                    xml('time',xml('beats','4' ).xml('beat-type', '4' )).
                    xml('staves','2').
                    xml('clef', {number=>1}, xml('line', '2' ).xml('sign','G')).
                    xml('clef', {number=>2}, xml('line', '4' ).xml('sign','F'))

                    ),
        notes=>[]

    };
    my $type_denominator = $self->denominator;
    while (1) {
        if (grep {$type_denominator == $_}(2,4,8,16,32,64,128,256) ) {
            last;
        } elsif($type_denominator>256) {
            die "$type_denominator to high. Above 256";
        } else {
            $type_denominator++;
        }
    }
    my $lasthand="unknown";
    my %endprev = (left=>$tick, right=>$tick);
    for my $tn(@{$self->notes}) {
        if ($tick + $tn->{delta_place_numerator} >= $self->denominator) {
            if ($tick - $endprev{ $tn->{hand} } > 0) {
                my $silence= {rest=>1};
                $silence->{duration} = $tick - $endprev{ $tn->{hand} };
                _populate_xml_type($silence,$tn,$type_denominator);
                push @{$measure->{$tn->{hand}}->{notes}}, $silence;
            }
            $tick += $tn->{delta_place_numerator} - $self->denominator;

            if (! $tick == 0) {
                say Dumper $tn;
                warn "\tick =$tick is not 0 $measure->{number}";
                last;
            }
            %endprev = (left=>$tick, right=>$tick);
            my $copy;
            %$copy = %$measure;
            $measure_number++;
            push @measures,$copy;
            $measure={ attributes=>'', number => $measure_number, denominator => $self->denominator, notes=>[] };
        } else {
            $tick += $tn->{delta_place_numerator};
        }
        if ($tick - $endprev{ $tn->{hand} } > 0) {
            my $silence= {rest=>1};
            $silence->{duration} = $tick - $endprev{ $tn->{hand} };
            _populate_xml_type($silence,$tn,$type_denominator);
            push @{$measure->{$tn->{hand}}->{notes}}, $silence;
        }

        $endprev{$tn->{hand}} = $tick + $tn->{length_numerator};
        my $wn = {};
        my $hand = $tn->{hand};
        if (!$hand) {
            warn Dumper $tn;
            die "Missing hand";
        }
        $wn->{duration} = $tn->{length_numerator};
        $wn->{chord} = 1 if $tn->{delta_place_numerator} == 0 && $lasthand eq $tn->{hand};
        _populate_xml_type($wn,$tn,$type_denominator);
        my @tnote =( $tn->{note_name}=~/^([A-Z])(\w)?(\d+)$/);
        if (@tnote == 3) {
            ($wn->{step},$wn->{alter},$wn->{octave})=@tnote;
            if (!exists $wn->{alter} ||! $wn->{alter}) {

            } elsif ($wn->{alter} eq 's') {
                $wn->{alter} = 1;
            } elsif($wn->{alter} eq 'm') {
                $wn->{alter} = -1;
            } else {
                die "Unkown alter $wn->{alter}. Must be either m,s";
            }
        } elsif (@tnote == 2) {
            ($wn->{step},$wn->{octave})=@tnote;
        }
        die "Unknown note_name". ($tn->{note_name}||'__EMPTY/UNDEF__') if ! $wn->{step};
        $wn->{step}='B' if $wn->{step} eq 'H';
        die $wn->{alter} if exists $wn->{alter} && $wn->{alter} && $wn->{alter} !~ /\w/;
        push @{$measure->{$hand}->{notes}}, $wn;
        $lasthand = $tn->{hand};
    }
    push @measures,$measure;

   my $txt =q|<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
    "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
    "http://www.musicxml.org/dtds/partwise.dtd">
|;
    $txt .=xml('score-partwise',{version=>"3.1"},
        xml('work',xml('work-title',$self->name))
        . xml('part-list', xml('score-part',{id=>'P1'},
            xml('part-name',$self->name))).
            xml('part', {'id' => 'P1'},
                join('',map{ xml_measure($_)} @measures)
            )
    );
}


#
sub _populate_xml_type($wn,$tn,$type_denominator) {
    if ($tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'whole';
    } elsif (2 *$tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'half';
    } elsif (4 *$tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'quarter';
    } elsif (8 *$tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'eighth';
    } elsif (16 *$tn->{length_numerator} == $type_denominator) {
        $wn->{type} = '16th';
    } elsif (4/3 * $tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'half';
        $wn->{dot} = 1;
    } elsif (8/3 * $tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'quarter';
        $wn->{dot} = 1;
    } elsif (16/3 * $tn->{length_numerator} == $type_denominator) {
        $wn->{type} = 'eighth';
        $wn->{dot} = 1;
    } elsif (! $tn->{length_numerator}) {
        $wn->{type} = '128th';
        $wn->{chord} = 1;
    } else {
        # TODO: Sjekk hvor lenge i gjen av takt og del note med bindebue. Ellers splitt med bindebue med færrest noter og første note er lengst.
        say STDERR Dumper $tn;
        warn "Unknown $tn->{length_numerator}  : " . $type_denominator;
        $wn->{type} = '128th';
    }
    return $wn;
}

=head2 to_string

Return a text with all notes and some general variables for the tune.

=cut


sub to_string {
	my $self = shift;
#	my $args = shift;

	my @notes;
	@notes = map{$_->to_string({scale => $self->{scale}, end =>"\n",count_first => ($self->startbeat?0:1),})} grep {$_} @{$self->notes};

	my $return='';
    for my $name (qw/denominator shortest_note_time beat_score scale startbeat
    	allowed_note_lengths allowed_note_types hand_left_max hand_right_min hand_default
    	comment name/) {

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

=head2 hand

    $tune->hand('right');
    say $tune->to_string;

Filter out the hand that is not mention.

=cut

sub hand {
    my $self = shift;
    my $hand = shift;
    my $data = $self->to_data_split_hands();
    $self->notes($data->{$hand});
    return $self;
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
