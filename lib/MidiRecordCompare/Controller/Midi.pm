package MidiRecordCompare::Controller::Midi;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

MidiRecordCompare::Controller::Midi - A start on a web page

=cut

=head1 SYNOPSIS

undercontruction.

=head1 DESCRIPTION

Under construction.


# This action will render a template

=head1 METHODS

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
