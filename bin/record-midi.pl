#!/usr/bin/env perl
use Mojo::Base  -strict;
use MIDI::Music;
use MIDI;
use Fcntl;

my $opus  = MIDI::Opus->new();
my $track = MIDI::Track->new();

my $mm = new MIDI::Music('tempo'    => 120, # These parameters
                         'realtime' => 1,   # can be passed to
                         );                 # the constructor

# Record some MIDI data from
# an external device..
$mm->init('mode' => O_RDONLY) || die $mm->errstr;
my $i=0;
for (;;) {

	$i++;
    last if ($i>100);

    my $event_struct = $mm->readevents;

    push(@{ $track->events_r }, @$event_struct)
        if (defined $event_struct);
}

$mm->close;

$opus->tracks($track);
$opus->write_to_file('bar.mid');