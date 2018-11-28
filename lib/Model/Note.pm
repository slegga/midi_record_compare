package Model::Note;
use Mojo::Base -base;
use Clone;
use Model::Utils::Scale;

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
has order =>0;  #lowest first
has 'hand';
#has tickpersec =>96;

use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

# TODO Flytt from_alsaevent ut i egen modul og endre navn til alsaevent2score
# returnerer en note i score format til bruk i Model::Tune->from_score

=head1 NAME

Model::Note - Handle notes alias a score

=head1 DESCRIPTION

Keep data for one note. Handle transaction etc.

=head1 ATTRIBUTES

=over

=item starttime

=item duration

=item note

=item velocity

=item delta_time

=item note_name

=item startbeat

=item length_numerator

=item delta_place_numerator

=item length_name

=item order

=back


=head1 METHODS

=head2 from_score {

Take an score-note as an array_ref.
options {shortest_note_time=>..., denominator}

score data is: 'note', starttime, duration, channel, note, velocity
Notefile data is: startbeat, length_numerator

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
    my $prev_startbeat = $options->{prev_startbeat} || 0;
    my $self =  $class->new(starttime => $score->[1] - ($options->{tune_starttime}//0)
    , duration => $score->[2], note =>$score->[4], velocity =>$score->[5]);
    my ($length_name, $length_numerator) =
        Model::Utils::calc_length( { time => $self->duration }, $options );
    $self->length_name($length_name);
    $self->length_numerator($length_numerator);
    #step up beat
    my $numerator = int( 1/2 + $self->delta_time / $options->{shortest_note_time} );
    my $startbeat = Model::Beat->new(denominator=>$options->{denominator});
    $startbeat = $startbeat + $numerator;
    $self->startbeat($startbeat->clone);
#    say Dumper $self;
    my $delta = $startbeat - $prev_startbeat;
    $self->delta_place_numerator($delta->to_int);
    if ( ! $options->{hand_split_on} ) {
    } elsif ($self->note < $options->{hand_split_on} ) {
    	$self->hand('left');
    } else {
    	$self->hand('right');
    }

    return $self;
}

=head2 to_hash_ref

	Return note as a hash_ref

=cut

sub to_hash_ref {
	my $self = shift;
	my $hash = {};
	for my $key(qw/starttime duration note velocity delta_time note_name startbeat length_numerator
	 delta_place_numerator length_name order/) {
	 	$hash->{$key} = $self->$key;
	}

	return $hash;
}

=head2 to_score

Return note in score format.
Return an array ref of array ref.

=cut

sub to_score {
    my $self = shift;
	my $opts = shift;
    my $factor = 1;
    if(defined  $opts && exists $opts->{factor} ) {
    	$factor = $opts->{factor};
    }

    #score:  ['note', startitme, length, channel, note, velocity],
    return ['note', $self->starttime * $factor, int($self->duration * $factor + 0.5), 0, $self->note, $self->velocity];
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
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,Model::Utils::Scale::value2notename($opts->{scale}//'c_dur',$self->note());
		if (! exists $opts->{no_comment} || ! $opts->{no_comment}) {
            my $format = '%-12s  #%4s-%3s';
            my $dt = $self->delta_time;
            my @args = ($core, $self->startbeat, $self->length_name);
            if (defined $dt && $dt) {
                $format .='%5s' ;
                push  @args, sprintf("-%.2f",$dt);
            }

		    $return =  sprintf $format,@args;
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
            $self->note(Model::Utils::Scale::notename2value($self->note_name));
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
