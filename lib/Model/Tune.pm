package Model::Tune;
use Mojo::Base -base;
use Mojo::File 'path';
use Model::Note;
use Model::Beat;
use Data::Dumper;
use Carp;
use List::Util qw/min max/;
use overload
    '""' => sub { shift->to_string }, fallback => 1;
has length => 0;
has shortest_note_time => 0;
has denominator => 4;
has beat_interval =>100000000;
has 'notes';
has midi_file  => '';
has note_file  => '';
has beat_score => 0;



=head1 DESCRIPTION

('note_off', dtime, channel, note, velocity)
('note_on',  dtime, channel, note, velocity)

=cut

=head2 calc_shortest_note

Guess the shorest note. If shorter than 96 it is a 1/8 else 1/4.

=cut


sub calc_shortest_note {
	my $self =shift;
	my $numnotes = $self->notes;

    my $max_try = max grep{$_&& $_>=30} map{ $_->{delta_time} } @$numnotes;
    my $min_try = min grep{$_&& $_>=10} map{ $_->{delta_time} } @$numnotes;
    my $try = int(($min_try+$max_try) / 2);
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
    warn $tmp;
    $tmp *=100;
    warn $tmp;
    $tmp=25 - $tmp;
    warn $tmp;
    $tmp=$tmp*4;
    warn $tmp;
    $self->beat_score( int ((25 -(100 * ($best->{value} / $numnotes)))*4 ));

	$self->shortest_note_time($best->{'period'});
    if ( $best->{'period'} >= 96 ) {
        $self->denominator(4);
    } elsif( $best->{'period'} < 96 ) {
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
              my ($ln,undef) = $self->_calc_length({numerator => $note->length_numerator});
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

=head2 from_midi_file

Take mididata and create events and create point in time from dtime

=cut


sub from_midi_file {
    my $class = shift;
    my $midi_filename = shift;
    my $events;
    my $score;
    my @notes;
    my $self = Model::Tune->new(midi_file => $midi_filename);
    if ($self->midi_file) {
        my $opus = MIDI::Opus->new({ 'from_file' => $self->midi_file, 'no_parse' => 1 });#
        my @tracks = $opus->tracks;
        # print $self->file . " has ", scalar( @tracks ). " tracks\n";
        my $data = $tracks[0]->data;
        $events = MIDI::Event::decode( \$data );
        $score = MIDI::Score::events_r_to_score_r( $events );
    }
    if (@$score) { #('note', starttime, duration, channel, note, velocity)
        my $tune_start;
		for my $sp(@$score) {#0=type,note,dtime,0,volumne
            next if $sp->[0] ne 'note';
            $tune_start=$sp->[1] if ! defined $tune_start;
		    push @notes, Model::Note->new(starttime => $sp->[1] - $tune_start
            , duration => $sp->[2], note =>$sp->[4], velocity =>$sp->[5]);

		  }
	}
	#    warn Dumper \@notes;
	@notes = sort { $a->{'starttime'} <=> $b->{'starttime'} }  @notes;

	$self->notes(\@notes);
	my $pre_time;
	for my $note (@notes) {
		if (! defined $pre_time) {
			$pre_time = $note->starttime;
			next;
		}
		$note->delta_time($note->starttime - $pre_time);
		$pre_time = $note->starttime;
	}
    return $self;
}

=head1 from_note_file

Create a new Model::Tune object baset on note file.
Dies if not file is set.

=cut

sub from_note_file {
    my $class = shift;
    my $self = $class->new(note_file => shift);
    die "note_file is not set" if ! $self->note_file;
    die "Cant be midi file" if $self->note_file =~/.midi?$/i;
    my $path = path( $self->note_file );

    # remove old comments
    my $content = $path->slurp;
    my $newcont='';
    my %input;
    my @notes = ();
    my $beat = Model::Beat->new(denominator=>$self->denominator);
    # Remove comments and add new
    for my $line (split/\n/,$content) {
      $line =~ s/\s*\#.*$//;
      next if ! $line;
      if ($line=~/([\w\_\-]+)\s*=\s*(.+)$/) {
          $self->$1($2);
      } else {
          my ($delta_place_numerator, $length_numerator, $note_name) = split(/\;/,$line);
          $beat = $beat + $delta_place_numerator;
          push(@notes,Model::Note->new(delta_place_numerator => $delta_place_numerator,
          length_numerator => $length_numerator,
          note_name => $note_name,
          denominator => $self->denominator//4, startbeat =>$beat->clone,
          )->compile);
      }

    #      $newcont .= Model::Note->new(delta_place_numinator => $val[0], length_numerator => $val[1], note => $val[2])
    #          ->to_string({expand=>1,denominator=>$input{denominator}});
    }
    say Dumper @notes;
    @notes = grep { defined $_ } @notes;
    die"No notes" if ! @notes;
    $self->notes(\@notes);
    return $self;
}




=head1 notes2score

Must either convert from events to score for the hole project or
do all in a function
Uses the note data to generate midi data as first MIDI::Score then events and then data
'note', starttime, duration, channel, note, velocity

=cut

sub notes2score {
	my $self = shift;
    my @notes = @ { $self->notes };

    # generate a temporary MIDI
    #(startbeat,length_numerator) => (starttime, duration)
    my @new_notes;
    my $prev_stime=0;
    for my $note (@notes) {
	    my $num = $note->startbeat->to_int;
# warn $num." * ".$self->shortest_note_time ;

        $note->starttime($note->startbeat->to_int * $self->shortest_note_time); #or shortest_note_time?
        $note->duration($note->length_numerator * $self->shortest_note_time - 5); #or shortest_note_time?
        $note->delta_time( $note->starttime - $prev_stime );
        $note->velocity(96); #hardcoded for now
        $prev_stime = $note->starttime;
        push(@new_notes, $note);
    }
    $self->notes(\@new_notes);
	return $self;
}

=head2 score2notes

Calculate notes as: point in time, length, sound
i.e
 denominator:4
 0.0;0.1;C4
 0.1;0.1;D4
...
Could maybe be replaced with MIDI::Score::quantize( $score_r )?


=cut

sub score2notes {
    my $self = shift;
    die "Missing denominator" if !$self->denominator;
    my $notes = $self->notes;
    my @notes = @$notes;
    my $startbeat = Model::Beat->new(denominator=>$self->denominator);
    for my $note(@notes) {
        my ($length_name, $length_numerator) = $self->_calc_length( { time => $note->duration } );
        $note->length_name($length_name);
        $note->length_numerator($length_numerator);
        #step up beat
        my $numerator = int( 1/2 + $note->delta_time / $self->shortest_note_time );
        $startbeat = $startbeat + $numerator;
        $note->startbeat($startbeat->clone);
    }
    @notes = sort {sprintf('%03d%02d%03d',$a->startbeat->number, $a->startbeat->numerator,128 - $a->note)
               cmp sprintf('%03d%02d%03d',$b->startbeat->number, $b->startbeat->numerator,128 - $b->note) } @notes;

    #loop another time through notes to calc delta_place_numerator after notes is sorted.
    my $prev_note = Model::Note->new(startbeat=>Model::Beat->new(number=>0, numerator=>0));
#    my @new_notes=();
    for my $note(@notes) {
		my $tb = $note->startbeat - $prev_note->startbeat;
		$note->delta_place_numerator($tb->to_int);
#		push(@new_notes, $note);
		$prev_note = $note;
    }

    $self->notes(\@notes);

    return $self;
}


=head2 to_midi_file

Takes midi filename. If none use $class->midi_file instead.
Write midi file to disk.

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
    for my $note(@{$self->notes}) {
        # ('note', starttime, duration, channel, note, velocity)
        push @$score_r, ['note', $note->starttime, $note->duration, 0, $note->note, $note->velocity//96];
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
	 {  'format' => 1,  'ticks' => $self->shortest_note_time, 'tracks' => [ $one_track ] }	);
        die "Missing midi_file. Do not know what todo" if (! $midi_file);
    $opus->dump;
    print '['.join (', ',@$_)."]\n" for  $opus->tracks_r()->[0]->events;
	$opus->write_to_file($midi_file);
    return $self;
}


sub to_note_file {
    my $self =shift;
    my $note_file = shift;
    $note_file = $self->note_file if ! $note_file;
    my $file =  path($note_file);
    say $file;
    my $content = $self->to_string;
    die "No content" if ! $content;
    $file->spurt($content);
    return $self;
}


sub to_string {
  my $self = shift;
  my @notes = map{"$_"} grep {$_} @{$self->notes};
	my $return= sprintf "denominator=%s\n", $self->denominator if $self->denominator;
	$return .=  sprintf "shortest_note_time=%s\n", $self->shortest_note_time if $self->shortest_note_time;
    $return .=  sprintf "beat_score=%s\n", $self->beat_score if $self->beat_score;
  return $return . join('',@notes)."\n";
}

#
#   PRIVATE SUBS
#

sub _calc_time_diff {
	my $self = shift;

  my $try = shift||confess"Miss try";
	my $notes = $self->notes;
	my @notes = @$notes;
	my $return=0;
	for my $note(@notes) {
		my $i = 1;
		my $nd = $note->delta_time;
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

# name _calc_length
# takes hash_ref (time=>100,numerator=4)
# Return (length_name,numerator) i.e. ('1/4',2)

sub _calc_length {
    my $self=shift;
    my $input=shift;
    my $numerator;
    if (exists $input->{'time'} ) {
      my $time = $input->{'time'};
       $numerator = int($time / $self->shortest_note_time + 6/10);
    } elsif(exists $input->{'numerator'}) {
      $numerator= $input->{'numerator'};
    } else {
      die 'Expect hash ref one key = (time|numerator)'
    }
     my $p = $numerator;
     my $s = $self->denominator;
     if ($s % 3 == 0) {
        $s=4 * $s / 3
     }
     while ($p %2 == 0 && $s % 2 == 0) {
         $p = $p /2;
         $s = $s /2;
     }
     return (sprintf("%d/%d",$p,$s), $numerator);

}

1;
