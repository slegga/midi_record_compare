package Model::Note;
use Mojo::Base -base;
use MIDI;
use Data::Dumper;
use Clone;

my $ALSA_CODE = {'SND_SEQ_EVENT_SYSTEM'=>0,'SND_SEQ_EVENT_RESULT'=>1
,'SND_SEQ_EVENT_NOTE'=>5,'SND_SEQ_EVENT_NOTEON'=>6,'SND_SEQ_EVENT_NOTEOFF'=>7};


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
#has tickpersec =>96;

use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

# TODO Flytt from_alsaevent ut i egen modul og endre navn til alsaevent2score
# returnerer en note i score format til bruk i Model::Tune->from_score

=head1 METHOD

=head2 from_score {

Take an score-note as an array_ref.

Do calculate notes values (see Model::Tune::notes2score)
Return a new Model::Note object.

=cut

sub from_score {
    my $class = shift;
    my $score = shift;
    my $options = shift;
    if ($score->[0] ne 'note') {
        warn Dumper $score;
        return;
    }
    my $self =  $class->new(starttime => $score->[1] - $options->{tune_starttime}
    , duration => $score->[2], note =>$score->[4], velocity =>$score->[5]);
    my ($length_name, $length_numerator) =
        $self->_calc_length( { time => $self->duration } );
    $self->length_name($length_name);
    $self->length_numerator($length_numerator);
    #step up beat
    my $numerator = int( 1/2 + $self->delta_time / $self->shortest_note_time );
    my $startbeat = Model::Beat->new(denominator=>$options->denominator);
    $startbeat = $startbeat + $numerator;
    $self->startbeat($startbeat->clone);
    say Dumper $self;
    my $delta = $startbeat - $options->{prev_startbeat};
    $self->delta_place_numerator($delta->to_int);
    return $self;
}

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
