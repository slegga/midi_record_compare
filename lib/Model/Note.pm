package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;

has time => 0;
has pitch => 0;
has volume => 0;
has length => 0;

use overload
    '""' => sub { shift->to_string }, fallback => 1;

sub to_string {
  my $self = shift;
  die Dumper $self if ! defined $self->pitch;
  return '' if $self->length<3;
  return $self->time.'-'.$self->length.'-'.$MIDI::number2note{ $self->pitch() }."-".$self->volume."\n";
}
1;
