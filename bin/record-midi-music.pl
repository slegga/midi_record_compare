#!/usr/bin/env perl
use Mojo::Base  -strict;
use MIDI::ALSA (':CONSTS');
use MIDI;
use Mojo::IOLoop;
use Fcntl;

MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
MIDI::ALSA::connectfrom( 0, 20, 0 );  # input port is lower (0)

my $opus  = MIDI::Opus->new();
my $track = MIDI::Track->new();


:# Record some MIDI data from
# an external device..

#MIDI::A
#Mojo::IOLoop->recurring(0 => sub {
#	;
#});
#Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
# Turn file descriptor into handle and watch if it becomes readable
my $handle = IO::Handle->new_from_fd( MIDI::ALSA::fd(), 'r');
Mojo::IOLoop->singleton->reactor->io($handle => sub {
  my ($reactor, $writable) = @_;
  say $writable ? 'Handle is writable' : 'Handle is readable';
  if (!$writable) {
       my @alsaevent = MIDI::ALSA::input();
        print "Alsa event: " . Dumper(\@alsaevent);

  }
})->watch($handle, 1, 0);

#$opus->tracks($track);
#$opus->write_to_file('bar.mid');
