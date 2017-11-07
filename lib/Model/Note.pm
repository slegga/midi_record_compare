package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;
use Clone;

# midi
has time => 0;
has pitch => 0;
has note_name =>'';
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
  my $return = '';
  die "Missing pitch" . Dumper $self if ! defined $self->pitch;
#  return '' if $self->length<3;
  if ($self->place_beat)  {
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,$MIDI::number2note{ $self->pitch() };

      $return =  sprintf "%-12s  #%4s",$core,$self->place_beat;
      if ($self->length) {
          $return .= sprintf "-%s-%4d-%3d-%3d",$self->length_name,$self->time,$self->length, $self->delta_time;
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
    if (! $self->pitch) {
        if ($self->note_name) {
            $self->pitch($MIDI::note2number{$self->note_name});
        } else {
            die"Must have pitch";
        }
    }
    return $self;
}

sub clone {
	my $self = shift;
	return clone $self;
}
1;
