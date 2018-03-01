package Model::Utils;
use Mojo::Base -strict;
use autodie;

our $ALSA_CODE = {      'SND_SEQ_EVENT_SYSTEM'      => 0
                    ,   'SND_SEQ_EVENT_RESULT'      => 1
                    ,   'SND_SEQ_EVENT_NOTE'        => 5
                    ,   'SND_SEQ_EVENT_NOTEON'      => 6
                    ,   'SND_SEQ_EVENT_NOTEOFF'     => 7
                    ,   'SND_SEQ_EVENT_CONTROLLER'  =>10   };

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
    die '$extra is not defiend ' . join(', ',@_) if ! defined $extra;
    my $dtime = $extra->{dtime_sec} * 96;
    if (   $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEON }) {
            #(type, starttime, duration, channel, note, velocity)
#        warn "NOTE ON";
#        my $starttime = int ($extra->{starttime} * 96);
        #my $duration = int($opts->{duration} *96);
        # ('note_on', dtime, channel, note, velocity)
        return ['note_on', $dtime, 0, $data->[1], $data->[2]];
    }
    if ( $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEOFF} ) {
#        warn "NOTE OFF";
#        my $starttime = int ($extra->{starttime} * 96);
#        my $duration = int($opts->{duration} *96);
        return ['note_off', $dtime, 0, $data->[1], $data->[2]];
    }
    say "Unregisered type = $type";
    return [$type, $dtime, 0, @$data ];
}

=head2 calc_length

Takes hash_ref (time=>100,numerator=4),
and options {shortest_note_time=>..., denominator=>...}
Return (length_name,numerator) i.e. ('1/4',2)

=cut

sub calc_length {
    my $input=shift;
    my $options = shift; #{shortest_note_time=>...,denominator=>...}
    die "ERROR: Calculate shortest_note_time before calling _calc_length" if ! $options->{shortest_note_time};
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

1;
