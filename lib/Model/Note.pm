package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;
use Clone;

# midi
has time => 0;
has pitch => 0;
has length =>0;
has volume => 0;
has delta_time => 0;

# note
has delta_place_numerator => 0;
has length_numerator => 0;
has length_name => '';
has place_beat => sub {return Model::Beat->new()};

use overload
    '""' => sub { shift->to_string }, fallback => 1;

sub to_string {
  my $self = shift;
  my $opts = shift;
  die Dumper $self if ! defined $self->pitch;
  return '' if $self->length<3;
  if ($self->place_beat)  {
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,$MIDI::number2note{ $self->pitch() };
      return sprintf "%-15s  #%4s-%s-%4d-%3d-%3d\n",$core,$self->place_beat,$self->length_name,$self->time,$self->length, $self->delta_time;
  }
  else  {
      return sprintf ";%s   %s-%s-%s-%s\n",$MIDI::number2note{ $self->pitch() },$self->time,$self->length,$self->volume,$self->delta_time;
      # time, length,note
      # 1 3/8;2/8;C4
      # opts={beatpart=>(12348)}
    
  }
}

sub clone {
	my $self = shift;
	return clone $self;
}
1;
