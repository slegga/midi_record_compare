package Model::Tune;
use Mojo::Base -base;
use Model::Note;
use Model::Beat;
use Data::Dumper;
use List::Util qw/min max/;
use overload
    '""' => sub { shift->to_string }, fallback => 1;
has 'events';
has length => 0;
has shortest_note_time => 0;
has beat => 4;
has time_diff =>100000000;
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
    print $self->file . " has ", scalar( @tracks ). " tracks\n";
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

    my $try = max grep{$_&& $_>=30} map{ $_->{delta_time} } @$numnotes;;
	my $best_diff = 10000000;
	
	my $diff = $self->_calc_time_diff($try);
	my $new_try=$try-1;
	
	while ($diff >= $self->_calc_time_diff($new_try)) {
		$diff= $self->_calc_time_diff($new_try);
		$try=$new_try;
		$new_try--;

	}
	$self->time_diff($diff);
	$numnotes = scalar @$numnotes;
	printf "%s -%s - %d - %d\n",$try,$diff, $numnotes, $diff / $numnotes;

	$self->shortest_note_time($try);
    if ($try>=96) {
        $self->beat(4);
    } elsif($try<96) {
        $self->beat(8);
    } 
	return $self;
}

sub _calc_time_diff {
	my $self = shift;
  
  my $try = shift||die;
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
        warn ":$i - nd:$nd - d1:$d1 - d2:$d2 - try:$try";
		$return += $d1;
	}
	warn "$try - $return";
	return $return;
}

=head2 events2notes

Calculate notes as: point in time, length, sound
i.e 
 beat:4
 0.0;0.1;C4
 0.1;0.1;D4
...

=cut

sub events2notes {
    my $self = shift;
    die "Missing beat" if !$self->beat;
    my $notes = $self->notes;
    my @notes = @$notes;
    my $beat = Model::Beat->new();
    for my $note(@notes) {
      $note->value($self->_calc_length($note->length));
			
			#step up beat
			my $beat_part = int( 1/2 + $note->delta_time / $self->shortest_note_time );
			warn $beat;
			$beat = $beat + $beat_part;
			warn $beat;
			$note->beat_place($beat->clone);
    }
    return $self;
}

sub _calc_length {
    my $self=shift;
    my $time=shift;
    
     my $p = int($time / $self->shortest_note_time + 6/10);
     my $s = $self->beat;
     if ($s % 3 == 0) {
        $s=4 * $s / 3
     }
     if ($p %2 == 0 && $s % 2 == 0) {
         $p = $p /2;
         $s = $s /2;
     }
     return sprintf "%d/%d",$p,$s;

}

sub to_string {
  my $self = shift;
  my @notes = map{"$_"} grep {$_} @{$self->notes};
  return join('',@notes);
}


1;
