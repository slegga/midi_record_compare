package Music::Utils;
use Mojo::Base -strict;
use Mojo::JSON qw/to_json/;
use autodie;

our $ALSA_CODE = {      'SND_SEQ_EVENT_SYSTEM'      => 0
                    ,   'SND_SEQ_EVENT_RESULT'      => 1
                    ,   'SND_SEQ_EVENT_NOTE'        => 5
                    ,   'SND_SEQ_EVENT_NOTEON'      => 6
                    ,   'SND_SEQ_EVENT_NOTEOFF'     => 7
                    ,   'SND_SEQ_EVENT_CONTROLLER'  =>10
                    ,   'SND_SEQ_EVENT_PGMCHANGE'   =>11
                    ,   'SND_SEQ_EVENT_SENSING'     =>42
                    ,   'SND_SEQ_EVENT_PORT_UNSUBSCRIBED'=>67
                };

=encoding utf8

=head1 NAME

Music::Utils - A place to store common functions.

=head1 SYNOPSIS

 use Music::Utils;
 ...;

=head1 DESCRIPTION

Place to put functions that does not belong else where.

=head1 FUNCTIONS

=head2 alsaevent2midievent

Read input from the MIDI::ALSA::input method. With HiRes tune_start,on and off
Return score as array_ref
('note_on', dtime, channel, note, velocity)
 ['note_on', 0, 0, 96, 25],

=cut

sub alsaevent2midievent {
    my ($type, $flags, $tag, $queue, $time, $source, $destination, $data, $extra) =@_;
    #@source = ( $src_client,  $src_port )
    # @destination = ( $dest_client,  $dest_port )
    # @data = ( varies depending on type )
    # score
    #die '$extra is not defiend ' . join(', ',@_) if ! defined $extra;
    my $dtime;
    $dtime = (ref $extra ? $extra->{dtime_sec} * 96 : $time * 1000 * 96);
    if (   $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEON } && $data->[2] ) {
            #(type, starttime, duration, channel, note, velocity)
#        warn "NOTE ON";
#        my $starttime = int ($extra->{starttime} * 96);
        #my $duration = int($opts->{duration} *96);
        # ('note_on', dtime, channel, note, velocity)
        return ['note_on', $dtime, 0, $data->[1], $data->[2]];
    }
    if ( $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEOFF} || ($type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEON } && ! $data->[2])) {
#        warn "NOTE OFF";
#        my $starttime = int ($extra->{starttime} * 96);
#        my $duration = int($opts->{duration} *96);
        return ['note_off', $dtime, 0, $data->[1], $data->[2]];
    }

    if ( $type == $ALSA_CODE->{SND_SEQ_EVENT_CONTROLLER}) {
#        warn "PEDAL";
#        my $starttime = int ($extra->{starttime} * 96);
#        my $duration = int($opts->{duration} *96);
        #('control_change', starttime, channel, controller(0-127), value(0-127))
        return ['control_change', $dtime, 0, $data->[4], $data->[5]];
    }

    if ( $type == $ALSA_CODE->{SND_SEQ_EVENT_PORT_UNSUBSCRIBED} ) {
        say "got SND_SEQ_EVENT_PORT_UNSUBSCRIBED: ".to_json(@_);
        return ['port_unsubscribed'];
    }
    if ( grep {$type == $_ } values %$ALSA_CODE ) {
        my $event_name = ( grep {$type == $ALSA_CODE->{$_} } keys %$ALSA_CODE )[0];
#        say "ignore $event_name: ".to_json(\@_);
        return;
    }
    say "Unregisered type = $type: " .to_json(\@_) ;
    return;
}

=head2 calc_length

Takes hash_ref (time=>100,numerator=4),
and options {shortest_note_time=>..., denominator=>...}
Return (length_name,numerator) i.e. ('1/4',2)

=cut

sub calc_length {
    my $input=shift;
    my $options = shift; #{shortest_note_time=>...,denominator=>...}
    die "ERROR: Calculate shortest_note_time before calling _calc_length ".($options->{shortest_note_time}//'__UNDEF__') if ! $options->{shortest_note_time};
    die "ERROR: Calculate denominator before calling _calc_length" if ! $options->{denominator};
    my $numerator;
    if (exists $input->{'time'} ) {
      my $time = $input->{'time'};
       $numerator = int($time / $options->{shortest_note_time} + 6/10);
    } elsif(exists $input->{'numerator'}) {
      $numerator= $input->{'numerator'};
    } else {
      die 'Expect hash ref one key = (time|numerator)'
    }
     my $p = $numerator;
     my $s = $options->{denominator};
     if ($s % 3 == 0) {
        $s=4 * $s / 3
     }
     while ($p %2 == 0 && $s % 2 == 0) {
         $p = $p /2;
         $s = $s /2;
     }
     return (sprintf("%d/%d",$p,$s), $numerator);

}

=head2 tune_as_text_validate

To be used for openapi interface to save files.

Returns 1 if valid and 0 if not valid tune

=cut

sub tune_as_text_validate {
	my $tune= shift;
	my @lines = split(/\n/, $tune);
    for my $l (@lines) {
        next if ( ! $l );
        next if ($l =~ /^\w+=\w+/);
        next if ($l =~ /^\d+\;\d+\;\w\d\s*/);
        next if ($l =~ /^\s*\#/);
        return 0;
    }
    return 1;
}

1;
