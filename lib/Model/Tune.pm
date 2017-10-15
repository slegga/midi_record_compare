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
    my @notes;
    for my $event(@{$self->events}) {#0=type,pitch,dtime,0,volumne
      next if !$event->[0] =~/^note_o(o|ff)$/;
      next if @$event<4;
      $time += $event->[1];
      if ($event->[4]) {
        $times[$event->[3]] = $time;
      } else {
        push @notes, Model::Note->new(time => $times[$event->[3]]
        , pitch =>$event->[3],length => $event->[1], volume =>$event->[4]);
      }
    }
    warn Dumper \@notes;
    $self->notes(\@notes);
  } else {
    confess("Nothing to do");
  }
  return $self;
}

sub to_string {
  my $self = shift;
  my @notes = map{"$_"} @{$self->notes};
  return join(' ',@notes);
}
1;
