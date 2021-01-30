package Music::Input::EventTest;
use Mojo::Base -base;

use Carp 'croak';


sub port { 1 }

sub register_events {
    my ($self,$loop,$controller) = @_;
    $loop->timer(0 => sub {
        my @events =(
        ['note_on', 0, 0, 96, 25],
        ['note_off', 0, 50, 96, 25],
        );

        $controller->register_midi_event($_) for @events;
    });
    $loop->timer(0.1 => sub {$controller->tune->finish});
    $loop->timer(0.2 => sub {$controller->do_quit});
}

sub init {  }

# do nothing as default.
sub reset_time {
}

1;

=encoding utf8

=head1 NAME

Music::Input::EventTest

=head1 SYNOPSIS

  use Mojo::Base 'Music::Input::EventTest';

  has port =>{ 80 };

  has register_events => {

  };

  sub input_init {
    my ($self, $app, $conf) = @_;

    # Magic here! :)
  }

=head1 DESCRIPTION

USB or other input system to get data from the piano.

=head1 METHODS

L<Mojolicious::Plugin> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 init

=head2 port

=head2 register_events

=head2 reset_time

Optional event when in need for reseting things when tune is finished played.

=cut
1;
