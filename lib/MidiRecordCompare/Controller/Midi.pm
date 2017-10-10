package MidiRecordCompare::Controller::Midi;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub upload_get {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}

sub upload_post {
  my $upload = Mojo::Upload->new;
  say $upload->filename;
  $upload->move_to($ENV{HOME}."/tmp");

}

1;
