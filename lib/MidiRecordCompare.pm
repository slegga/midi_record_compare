package MidiRecordCompare;
use Mojo::Base 'Mojolicious';
use Mojo::Upload;
use Mojo::File;
use FindBin;
use lib "$FindBin::Bin/../lib";

# This method will run once at server start

=head1 NAME

MidiRecordCompare

=head1 SYNOPSIS

...;
under construction;

=head1 DESCRIPTION

Main web class. Under construction.

=head1 METHODS

=head2 startup

app startup

sudo apt-get install libasound2-dev

=cut

sub startup {
  my $self = shift;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};


  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('midi#upload_get');
  $r->post('/')->to('midi#upload_post');
}

1;
