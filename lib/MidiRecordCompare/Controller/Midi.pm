package MidiRecordCompare::Controller::Midi;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

MidiRecordCompare::Controller::Midi - A start on a web page

=cut




# This action will render a template

=head2 upload_get

=cut

sub upload_get {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}

=head2 upload_post

=cut

sub upload_post {
  my $upload = Mojo::Upload->new;
  say $upload->filename;
  $upload->move_to($ENV{HOME}."/tmp");

}

1;
