package Model::Tune;
use Mojo::Base -base;
use Model::Note;
use Data::Dumper;
use overload
    '""' => sub { shift->to_string }, fallback => 1;
has 'events';
has length => 0;
has shortest_note => 0;
has longest_note => 0;
has 'notes';
has file => '';

=head1 DESCRIPTION

('note_off', dtime, channel, note, velocity)
('note_on',  dtime, channel, note, velocity)

=head1 compile

Generate notes from file or events;

=cut

sub compile {
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
  } else {
    confess("Nothing to do");
  }
  return $self;
}

sub to_string {
  my $self = shift;
  my @notes = map{"$_"} grep {$_} @{$self->notes};
  return join(' ',@notes);
}
1;
