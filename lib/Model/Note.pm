package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;
use Clone;

# midi
has starttime => 0;
has duration => 0;
has note => 0;
has velocity => 0;
has delta_time => 0;
has note_name =>'';


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
  my $return = '';
  die "Missing note" . Dumper $self if ! defined $self->note;
#  return '' if $self->length<3;
  if ($self->place_beat)  {
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,$MIDI::number2note{ $self->note() };

      $return =  sprintf "%-12s  #%4s",$core,$self->place_beat;
      if ($self->duration) {
          $return .= sprintf "-%s-%4d-%3d-%3d",$self->length_name,$self->starttime,$self->duration, $self->delta_time;
      }
  } else {
      ...;
  }
  return $return."\n";
}

=head2 compile

Calculate and fill missing values if able.

=cut

sub compile {
    my $self = shift;
    if (! $self->note) {
        if ($self->note_name) {
            $self->note($MIDI::note2number{$self->note_name});
        } else {
            die"Must have note";
        }
    }
    return $self;
}

sub clone {
	my $self = shift;
	return clone $self;
}
1;
