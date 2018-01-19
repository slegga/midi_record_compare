#!/usr/bin/env perl
use Mojo::Base '-base';

use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use MIDI::ALSA(':CONSTS');

=head1 NAME

=head1 DESCRIPTION

=head1 INSTALL GUIDE

sudo apt install libasound2-dev

cpanm MIDI::ALSA

=cut

has file_count => 0;
has exists_tune => 0;
has file  => sub { shift->file_start('0_START.pgm') };
has loop  => sub { Mojo::IOLoop->singleton };
has alsa_port => sub {my $con =`aconnect -i`;
    (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0]};
has alsa_stream => sub {my $r = IO::Handle->new;$r->fdopen(MIDI::ALSA::fd(),'r'); warn $r->error if $r->error;return $r};
has alsa_loop  => sub { my $self=shift;Mojo::IOLoop::Stream->new($self->alsa_stream)->timeout(0) };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has tune => sub {Model::Tune->new};
has midi_events => sub {[]};

__PACKAGE__->new->main;

sub main {
  my $self = shift;
  say $self->alsa_port;
  die "Did not find the midi input stream! Need port number." if ! defined $self->alsa_port;
  MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
  MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)
  say dumper $self->alsa_stream;

  $self->alsa_loop->on( read => sub { $self->alsa_read(@_)  });
  $self->alsa_loop->start;

  $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });
  $self->stdin_loop->start;

  $self->loop->start unless $self->loop->is_running;

}

# Read note pressed.
sub alsa_read {
    my ($self, $stream, $bytes) = @_;
    while (MIDI::ALSA::inputpending()) {
	    my @alsaevent = MIDI::ALSA::input();
	    print "Alsa event: " . dumper(\@alsaevent);
	    my $event = MIDI::ALSA::alsa2scoreevent( @alsaevent );
	    push( @{$self->midi_events}, $event);
	    print dumper $event;
	}
}

# Stop existing tune
# analyze
# print
sub stdin_read {
    my ($self, $stream, $bytes) = @_;
    my $tune = Model::Tune->from_midi_events($self->midi_events,{});
    say "Got input!";
    $tune->calc_shortest_note;
    $tune->score2notes;
    print $tune->to_string;
	$self->midi_events([]); # clear history
}


__END__
use MIDI;
use strict;
use warnings;
my @events = (
  ['text_event',0, 'MORE COWBELL'],
  ['set_tempo', 0, 450_000], # 1qn = .45 seconds
);

for (1 .. 20) {
  push @events,
    ['note_on' , 90,  9, 56, 127],
    ['note_off',  6,  9, 56, 127],
  ;
}
foreach my $delay (reverse(1..96)) {
  push @events,
    ['note_on' ,      0,  9, 56, 127],
    ['note_off', $delay,  9, 56, 127],
  ;
}

my $cowbell_track = MIDI::Track->new({ 'events' => \@events });
my $opus = MIDI::Opus->new(
 { 'format' => 0, 'ticks' => 96, 'tracks' => [ $cowbell_track ] } );
$opus->write_to_file( 'cowbell.mid' );
