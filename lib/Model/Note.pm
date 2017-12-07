package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;
use Clone;

# score
has starttime => 0;
has duration => 0;
has note => 0;
has velocity => 0;

# score help
has delta_time => 0;
has note_name =>'';

# note
has startbeat => sub {return Model::Beat->new()};
has length_numerator => 0;

#note help
has delta_place_numerator => 0;
has length_name => '';

use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

=head1 METHOD

=head2 to_string

Print a line representing a note. delta_place_numerator,length_numerator,note.
Additional comment is startbeat-length_name

=cut

sub to_string {
	my $self = shift;
	my $opts = shift;
	my $return = '';
	die "Missing note" . Dumper $self if ! defined $self->note;
	#  return '' if $self->length<3;
	if ($self->startbeat)  {
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,$MIDI::number2note{ $self->note() };
		if (! exists $opts->{no_comment} || ! $opts->{no_comment}) {
		    $return =  sprintf "%-12s  #%4s-%s",$core,$self->startbeat,$self->length_name;
		}
		else {
			$return =  $core;
		}
	} else {
	    ...;
	}
	return $return.(exists $opts->{end}? $opts->{end}: '');
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

=head2 clone

Clone. Copy and return a new object.

=cut

sub clone {
	my $self = shift;
	return clone $self;
}
1;
