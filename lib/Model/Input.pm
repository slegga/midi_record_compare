package Model::Input;
use Mojo::Base -base;

use Carp 'croak';

sub register { croak 'Method "register" not implemented by subclass' }

1;

=encoding utf8

=head1 NAME

Model::Input

=head1 SYNOPSIS

  package Model::Input::ALSA;
  use Mojo::Base 'Model::Input';

  has input_port => sub{22};
  has input_stream => sub {sub{}};

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

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
