package Model::Input;
use Mojo::Base -base;

use Carp 'croak';

sub port { croak 'Method "port" not implemented by subclass' }

sub register_events { croak 'Method "register_events" not implemented by subclass' }

sub init { croak 'Method "init" not implemented by subclass' }

1;

=encoding utf8

=head1 NAME

Model::Input

=head1 SYNOPSIS

  package Model::Input::ALSA;
  use Mojo::Base 'Model::Input';

  sub port =>{ 80 };

  sub register_events => {
  
  }

  sub

  sub input_init {
    my ($self, $app, $conf) = @_;

    # Magic here! :)
  }

=head1 DESCRIPTION


=head1 METHODS

L<Mojolicious::Plugin> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);
  $plugin->register(Mojolicious->new, {foo => 'bar'});

This method will be called by L<Mojolicious::Plugins> at startup time. Meant to
be overloaded in a subclass.

=cut
1;
