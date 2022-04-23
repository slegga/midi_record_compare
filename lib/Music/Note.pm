package Music::Note;
use Mojo::Base -base;
use Clone;
use Music::Utils::Scale;
use Data::Dumper;


my $ALSA_CODE = {'SND_SEQ_EVENT_SYSTEM'=>0,'SND_SEQ_EVENT_RESULT'=>1
,'SND_SEQ_EVENT_NOTE'=>5,'SND_SEQ_EVENT_NOTEON'=>6,'SND_SEQ_EVENT_NOTEOFF'=>7};


# score
#has starttime => 0;
#has duration => 0;
has note => 0;
has velocity => 0;

# score help
#has delta_time => 0;
has note_name =>'';

# note
has startbeat => sub {
    return Music::Position->new( count_first => shift->count_first );
};
has length_numerator => 0;

#note help
has delta_place_numerator => 0;
has length_name => '';
has 'hand';
has ['next_silence','stacato']; # used by colornotes.pl script
#has 'type'; # currently null or storing
has 'string'; #string like __END__
has count_first =>1;
#has tickpersec =>96;
has type => 'note'; # note,control_change,string. default note

use overload
    '""' => sub { shift->to_string({end=>"\n"}) }, fallback => 1;

# TODO Flytt from_alsaevent ut i egen modul og endre navn til alsaevent2score
# returnerer en note i score format til bruk i Music::Tune->from_score

=head1 NAME

Music::Note - Handle notes alias a score

=head1 SYNOPSIS

    use Music::Note;
    my $note = Music::Note->new( startposition=>0, length_numerator =>4 );
    say $note->to_string;

=head1 DESCRIPTION

Keep data for one note. Handle transaction etc.

=head1 ATTRIBUTES

=over

=item starttime

=item duration

=item note
    a number reflecting note which is played

    -1 left pause
    -2 right pause
    -3 right pedal

=item velocity

=item delta_time

=item note_name

=item startbeat

=item length_numerator

=item delta_place_numerator

=item length_name

=item order

=item type

=back


=head1 METHODS

=head2 from_score {

Take an score-note as an array_ref.
options {shortest_note_time=>..., denominator}

score data is: 'note', starttime, duration, channel, note, velocity
Notefile data is: startbeat, length_numerator

Do calculate notes values (see Music::Tune::notes2score)
Return a new Music::Note object.

=cut

sub from_score {
    my $class = shift;
    my $score = shift;
    my $options = shift;
    if ($score->[0] ne 'note' && $score->[0] ne 'control_change') {
        warn Dumper $score;
        die;
        return;
    }
    my $prev_startbeat = $options->{prev_startbeat} || 0;
    my $self =  $class->new(starttime => $score->[1] - ($options->{tune_starttime}//0)
    , note =>$score->[4], velocity =>$score->[5], type=>$score->[0]);
    my ($length_name, $length_numerator) =
        Music::Utils::calc_length( { time => $score->[2] }, $options );
    $self->length_name($length_name);
    $self->length_numerator($length_numerator);
    #step up beat
    my $numerator = int( 1/2 + ($score->[1] - $options->{prev_starttime}) / $options->{shortest_note_time} );
    my @suboptions =(denominator=>$options->{denominator});
    push @suboptions,(count_first=>0) if exists $options->{count_first} &&  $options->{count_first} ==0;
    my $startbeat = Music::Position->new(@suboptions);
    $startbeat = $startbeat + $numerator;
    $self->startbeat($startbeat->clone);
#    say Dumper $self;
    my $delta = $startbeat - $prev_startbeat;
    $self->delta_place_numerator($delta->to_int);
    if ( $score->[0] ne 'note') {
        warn Dumper $score;
        ...; # make code for pedal
    }
    elsif ( ! $options->{hand_split_on}  ) {

    } elsif ($self->note < $options->{hand_split_on} ) {
        ...; # should calculate hand
    	$self->hand('left');
    } else {
    	$self->hand('right');
    }

    return $self;
}

=head2 order

Return a unique number for ordering/sorting notes in a note paper/file.

=cut

sub order {
    my $self = shift;
    shift && die "No more arguments";
    return $self->startbeat->to_int * 1000 -250 if $self->type ne 'note';

    return $self->startbeat->to_int * 1000 + 128 - $self->note;
}

=head2 to_hash_ref

	Return note as a hash_ref

=cut

sub to_hash_ref {
	my $self = shift;
	my $hash = {};
	for my $key(qw/note note_name startbeat length_numerator
	 delta_place_numerator length_name order type/) {
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
    return [$self->type, $self->starttime * $factor, int($self->duration * $factor + 0.5), 0, $self->note, $self->velocity];
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
    if ($self->type && $self->type eq 'string') {
        $return = $self->string;
	} elsif ($self->startbeat)  {
		my $core = sprintf "%s;%s;%s",$self->delta_place_numerator,$self->length_numerator,Music::Utils::Scale::value2notename($opts->{scale}//'c_dur',$self->note());
		if (! exists $opts->{no_comment} || ! $opts->{no_comment}) {
            my $format = '%-12s  #%4s-%3s';
            my @args = ($core, $self->startbeat, $self->length_name);
            if ( $self->hand) {
                $format .=' %-5s';
                push @args, $self->hand;
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
        if (! $self->type ) {
        warn Dumper $self;
        die "All notes must have a type. Consider setting type to note if notename";
        }
        elsif ($self->type eq 'control_change') {
            ...;
        }
        elsif ($self->type eq 'note') {#$self->note_name =~/\w/) {
            my $val = Music::Utils::Scale::notename2value($self->note_name);
            $self->note($val);
        } elsif($self->type eq 'PL') {
            $self->note(-1); # left pause
            $self->note_name('PL');
        } elsif($self->type eq 'PR') {
            $self->note(-2); # right pause
            $self->note_name('PR');
        } elsif($self->type eq 'PD') {
            $self->note(-3); # right pedal
            $self->note_name('PD');
        } elsif($self->type eq 'string') {
            $self->note($self->string);
        } else {
            warn Dumper $self;
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
	my %params;
#	has note => 0;
#	has velocity => 0;
#	has note_name =>'';
#	has startbeat => sub {
#	    return Music::Position->new( count_first => shift->count_first );
#	};
	# has length_numerator => 0;
	# has delta_place_numerator => 0;
	# has length_name => '';
	# has 'hand';
	# has ['next_silence','stacato']; # used by colornotes.pl script
	# has 'type'; # currently null or storing
	# has 'string'; #string like __END__
	# has count_first =>1;

	for my $key (qw/note velocity length_numerator delta_place_numerator length_name string/) {
	    $params{$key}= $self->$key;
	}
	my $startbeat = Music::Position->new(integer=>$self->startbeat->integer);
	my $x =  $self->new(%params, startbeat => $startbeat);
	return $x;
}
1;
