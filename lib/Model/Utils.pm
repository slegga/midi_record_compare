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
1;
