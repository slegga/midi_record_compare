package Model::Utils;
use Mojo::Base -strict;
use autodie;

our $ALSA_CODE = {      'SND_SEQ_EVENT_SYSTEM'      => 0
                    ,   'SND_SEQ_EVENT_RESULT'      => 1
                    ,   'SND_SEQ_EVENT_NOTE'        => 5
                    ,   'SND_SEQ_EVENT_NOTEON'      => 6
                    ,   'SND_SEQ_EVENT_NOTEOFF'     => 7
                    ,   'SND_SEQ_EVENT_CONTROLLER'  =>10   };

=head2 alsaevent2scorenote

Read input from the MIDI::ALSA::input method. With HiRes tune_start,on and off
Return score as array_ref

 (type, starttime, duration, channel, note, velocity)
 ['note', 0, 96, 1, 25, 96],

=cut

sub alsaevent2scorenote {
    my ($type, $flags, $tag, $queue, $time, $source, $destination, $data, $opts) =@_;
    #@source = ( $src_client,  $src_port )
    # @destination = ( $dest_client,  $dest_port )
    # @data = ( varies depending on type )
    # score
    if (   $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEON }
        || $type == $ALSA_CODE->{SND_SEQ_EVENT_NOTEOFF} ) {
            #(type, starttime, duration, channel, note, velocity)
        my $starttime = int ($opts->{starttime} * 96);
        my $duration = int($opts->{duration} *96);
        return ['note', $starttime, $duration, 0, $data->[1], $data->[2]];
    }
    warn "type = $type";
    return [$type, $flags, $tag, $queue, $time, $data, $opts ];
}

=head2 calc_length

Takes hash_ref (time=>100,numerator=4),
and options {shortest_note_time=>..., denominator=>...}
Return (length_name,numerator) i.e. ('1/4',2)

=cut

sub calc_length {
    my $input=shift;
    my $options = shift; #{shortest_note_time=>...,denominator=>...}
    die "Calculate shortest_note_time before calling _calc_length" if ! $options->{shortest_note_time};
    die "Calculate denominator before calling _calc_length" if ! $options->{denominator};
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
