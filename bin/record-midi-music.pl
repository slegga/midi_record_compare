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

has file  => sub { shift->file_start('0_START.pgm') };
has loop  => sub { Mojo::IOLoop->singleton };
has alsa_port => sub {my $con =`aconnect -o`;
    (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} split(/\n/, $con))[0]};
has alsa_stream => sub {my $r = IO::Handle->new;$r->fdopen(MIDI::ALSA::fd(),'r'); warn $r->error if $r->error;return $r};
has alsa => sub { my $self=shift;Mojo::IOLoop::Stream->new($self->alsa_stream)->timeout(0) };

__PACKAGE__->new->main;

sub main {
  my $self = shift;
  say $self->alsa_port;
  MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
  MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)
  say dumper $self->alsa_stream;
  $self->alsa->on(read => sub {
    my @alsaevent = MIDI::ALSA::input();
print "Alsa event: " . Dumper(\@alsaevent) });
  $self->alsa->start;
  $self->loop->start unless $self->loop->is_running;
}

sub file_start {
  my ($self, $path) = @_;
  $self->file_count($self->file_count + 1);
  return Mojo::Asset::File->new(path => $path)->cleanup(0)->add_chunk(
    data_section(__PACKAGE__, 'pgm_header'),
  );
};

sub stdin_read {
  my ($self, $stream, $bytes) = @_;

  foreach my $packet (split /\n/, $bytes) {
    my $chunk = join ' ', (
      map { sprintf '%03i', hex($_) } split /:/, $packet
    );
    $self->file->add_chunk($chunk . "\n");
  }
}

__DATA__

@@ pgm_header
P2
00000000 00000000
255

@@ instructions
1 Prepare for instructions, cherished aide!
3 Steady

2 Prep Yaw
5 Start Yaw
1 Stop Yaw
3 Steady

2 Prep Pitch
5 Start Pitch
1 Stop Pitch
3 Steady

2 Prep Roll
5 Start Roll
1 Stop Roll
3 Steady

2 Prep Sway
5 Start Sway
1 Stop Sway
3 Steady

2 Prep Surge
5 Start Surge
1 Stop Surge
3 Steady

2 Prep Heave
5 Start Heave
1 Stop Heave
3 Steady

0 The End Of Instructions. Thank you, generous one!
