#!/usr/bin/env perl
use Mojo::Base '-base';

use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;

use Mojo::Loader 'data_section';

has file_count => 0;

has file  => sub { shift->file_start('0_START.pgm') };
has loop  => sub { Mojo::IOLoop->singleton };
has stdin => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };

__PACKAGE__->new->main;

sub main {
  my $self = shift;
  $self->stdin->on(read => sub { $self->stdin_read(@_) });
  $self->stdin->start;
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
