package Music::Input;
use Mojo::Base -base;

use Carp 'croak';

sub port { croak 'Method "port" not implemented by subclass' }

sub register_events { croak 'Method "register_events" not implemented by subclass' }

sub init { croak 'Method "init" not implemented by subclass' }

# do nothing as default.
sub reset_time {
}

1;

=encoding utf8

=head1 NAME

Music::Input

=head1 SYNOPSIS

  package Music::Input::ALSA;
  use Mojo::Base 'Music::Input';

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
