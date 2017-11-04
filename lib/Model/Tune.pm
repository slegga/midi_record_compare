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
has 'events';
has length => 0;
has shortest_note_time => 0;
has denominator => 4;
has beat_interval =>100000000;
has 'notes';
has file => '';

=head1 DESCRIPTION

('note_off', dtime, channel, note, velocity)
('note_on',  dtime, channel, note, velocity)

=head1 compile

Generate notes from file or events;

=cut

=head2 data2events

Take mididata and create events and create point in time from dtime

=cut


sub data2events {
  my $self = shift;
  if ($self->file) {
    my $opus = MIDI::Opus->new({ 'from_file' => $self->file, 'no_parse' => 1 });
    my @tracks = $opus->tracks;
    # print $self->file . " has ", scalar( @tracks ). " tracks\n";
    my $data = $tracks[0]->data;
    $self->events(MIDI::Event::decode( \$data ));
  }
  if (@{$self->events}) {
    my $time = 0;
    my @times=map{0} 0..127;
    my @volumes=map{0} 0..127;
    my @notes;
    for my $event(@{$self->events}) {#0=type,pitch,dtime,0,volumne
      next if $event->[0] !~ /^note_o(n|ff)/;
#      printf "%s %s %s %s %s\n",@$event;

      next if @$event<5;
      $time += $event->[1];
      if ($event->[4]) {
        $times[$event->[3]] = $time;
        $volumes[$event->[3]] = $event->[4];
      } else {
        push @notes, Model::Note->new(time => $times[$event->[3]]
        , pitch =>$event->[3],length =>$time - $times[$event->[3]], volume =>$volumes[$event->[3]]);

      }
    }
#    warn Dumper \@notes;
    @notes = sort { $a->{'time'} <=> $b->{'time'} }  @notes;

    $self->notes(\@notes);
		my $pre_time;
		for my $note (@notes) {
			if (! defined $pre_time) {
				$pre_time = $note->time;
				next;
			}
			$note->delta_time($note->time - $pre_time);
			$pre_time = $note->time;

		}
  } else {
    confess("Nothing to do");
  }
  return $self;
}

=head2 calc_shortest_note

Guess the shorest note. If shorter than 96 it is a 1/8 else 1/4.

=cut

sub calc_shortest_note {
	my $self =shift;
	my $numnotes = $self->notes;

    my $max_try = max grep{$_&& $_>=30} map{ $_->{delta_time} } @$numnotes;
    my $try = int($max_try / 2);
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

    if ($best->{value} / $numnotes >=0.1 ) {
       $try = $best->{'period'};
	my $diff = $self->_calc_time_diff($try);
       my $new_try=$try-1;
       while ($diff >= $self->_calc_time_diff($new_try)) {
               $diff= $self->_calc_time_diff($new_try);
               $try=$new_try;
               $new_try--;
		}
		$best={'period' => $try};
       $self->beat_interval($diff);
       printf "method 2: p:%s -d:%s - nn:%d - dd:%d\n",$try,$diff, $numnotes, $diff / $numnotes;
	}
	$self->shortest_note_time($best->{'period'});
    if ( $best->{'period'} >= 96 ) {
        $self->denominator(4);
    } elsif( $best->{'period'} < 96 ) {
        $self->denominator(8);
    }
	return $self;
}

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

=head2 events2notes

Calculate notes as: point in time, length, sound
i.e
 denominator:4
 0.0;0.1;C4
 0.1;0.1;D4
...

=cut

sub events2notes {
    my $self = shift;
    die "Missing denominator" if !$self->denominator;
    my $notes = $self->notes;
    my @notes = @$notes;
    my $denominator = Model::Beat->new(denominator=>$self->denominator);
    for my $note(@notes) {
        my ($length_name, $length_numerator) = $self->_calc_length( { time => $note->length } );
        $note->length_name($length_name);
        $note->length_numerator($length_numerator);
        #step up beat
        my $numerator = int( 1/2 + $note->delta_time / $self->shortest_note_time );
        $denominator = $denominator + $numerator;
        $note->place_beat($denominator->clone);
    }
    @notes = sort {sprintf('%03d%02d%03d',$a->place_beat->number, $a->place_beat->numerator,128 - $a->pitch)
               cmp sprintf('%03d%02d%03d',$b->place_beat->number, $b->place_beat->numerator,128 - $b->pitch) } @notes;

    #loop another time through notes to calc delta_place_numerator after notes is sorted.
    my $prev_note = Model::Note->new(place_beat=>Model::Beat->new(number=>0, numerator=>0));
    for my $note(@notes) {
      my $tb = $note->place_beat - $prev_note->place_beat;
      $note->delta_place_numerator($tb->to_int);

      $prev_note = $note;
    }

    $self->notes(\@notes);

    return $self;
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

=head2 clean

Modify tune after sertant rules like extend periods defined in opts argument.
Opts is a has ref, can have these options: extend, nobeattresspass, upgrade 0/1.

=cut

sub clean {

    my $self = shift;
    my $opts = shift;
    my $place_beat = Model::Beat->new(denominator=>$self->denominator);
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
        $place_beat = $place_beat + $note->delta_place_numerator;
        $note->place_beat($place_beat->clone);
      }
      $self->notes(\@notes);
    }

    return $self;
}

sub to_string {
  my $self = shift;
  my @notes = map{"$_"} grep {$_} @{$self->notes};
	my $return= sprintf "denominator=%s\n", $self->denominator if $self->denominator;
	$return .=  sprintf "shortest_note_time=%s\n", $self->shortest_note_time if $self->shortest_note_time;
  return $return . join('',@notes)."\n";
}

=head1 notes_from_file

Import notes from a note file. file is defined in new or as aparameter.
Dies if not file is set.

=cut

sub notes_from_file {
  my $self = shift;
  die "file is not set" if ! $self->file;
  die "Cant be midi file" if $self->file =~/.midi?$/i;
  my $path = path( $self->file );

  # remove old comments
  my $content = $path->slurp;
  my $newcont='';
  my %input;
  my @notes = ();
  # Remove comments and add new
  for my $line (split/\n/,$content) {
      $line =~ s/\s*\#.*$//;
      next if ! $line;
      if ($line=~/([\w\_\-]+)\s*=\s*(.+)$/) {
          $self->$1($2);
      } else {
          my ($delta_place_numinator, $length_numerator, $note_name) = split(/\;/,$line);
          push(@notes,Model::Note->new(delta_place_numinator => $delta_place_numinator,
          length_numerator => $length_numerator,
          note_name => $note_name,
          denominator => $self->denominator//4,
          )->compile);
      }

#      $newcont .= Model::Note->new(delta_place_numinator => $val[0], length_numerator => $val[1], pitch => $val[2])
#          ->to_string({expand=>1,denominator=>$input{denominator}});
  }
  say Dumper @notes;
    @notes = grep { defined $_ } @notes;
  die"No notes" if ! @notes;
    $self->notes(\@notes);
    say "$self";
}

1;
