package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;

has time => 0;
has pitch => 0;
has volume => 0;
has length => 0;
has delta_time => 0;
has beat_point => sub {return Model::Beat->new()};

use overload
    '""' => sub { shift->to_string }, fallback => 1;

sub to_string {
  my $self = shift;
  my $opts = shift;
  die Dumper $self if ! defined $self->pitch;
  return '' if $self->length<3;
  if (! $opts) {
      return sprintf "%s-%s-%s-%s-%s\n",$self->time,$self->length,$MIDI::number2note{ $self->pitch() },$self->volume,$self->delta_time;
  } else {
      # time, length,note
      # 1 3/8;2/8;C4
      # opts={beatpart=>(12348)}
    
  }
}
1;
