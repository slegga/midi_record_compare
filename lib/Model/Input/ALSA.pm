package Model::Input::ALSA;
use Mojo::Base 'Model::Input';
use Mojo::JSON 'to_json';
use MIDI::ALSA(':CONSTS');

=head1 NAME

Model::Input::ALSA

=head1 SYNOPSIS

use Model::Input::ALSA
...;

=head1 DESCRIPTION

"Input plugin" for Mojo::IOLoop for ALSA protocoll for reading .

inherits all methods from Model::Input and override following methods.

[type, flags, tag, queue, time, source, destination, data] ALSA

=cut

=head1 ATTRIBUTES

=cut

has tune_starttime => 0;
has last_event_starttime => 0;


=head1 METHODS

=head2 port

Return port.

=cut



sub port {
    my $return;
    my $state='new';
    while (! defined $return) {
        my $con=`aconnect -i`;
        #warn $con;
        $return = (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0];
        if (! defined $return and $state eq 'new') {
            $state='warned';
            say "Missing port. Waiting for Piano to connect. Please secure that piano is turned on.";

        }
    }
    return $return;
}

# sub alsa_stream {
#      my $r = IO::Handle->new;
#      $r->fdopen(MIDI::ALSA::fd(),'r');
#      warn $r->error if $r->error;
#      return $r
#  }

=head2 init

Initialize ALSA
lissening.

=cut

 sub init {
    my ($self) = @_;
         say "input port: ".$self->port();
         MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
         MIDI::ALSA::connectfrom( 0, $self->port, 0 );  # input port is lower (0)
         MIDI::ALSA::start() or die "start failed";

}

sub register_events {
    my ($self,$loop, $controller) = @_;
    $loop->recurring(0 => sub {
        my ($self) = shift;
        if (MIDI::ALSA::inputpending()) {
            $self->emit('alsaread', $controller) ;
        }
    });
    $loop->on( alsaread => sub {
        $self->alsa_read(@_)
    });

}

=head2 alsa_read



=cut

sub alsa_read {
    my ($self,$loop,$controller) = @_;
    my $on_time = Time::HiRes::time;

    # reset timer
    $controller->silence_timer(0);

    my @alsaevent = MIDI::ALSA::input();
    $self->tune_starttime($on_time) if ! $self->tune_starttime();
    push @alsaevent,{dtime_sec=>
    	($on_time - ($self->last_event_starttime||$self->tune_starttime))};
    my $event = Model::Utils::alsaevent2midievent(@alsaevent);
    $self->last_event_starttime($on_time) if $event;
    $controller->register_midi_event($event);
}

sub reset_time {
    my ($self) = @_;
    $self->tune_starttime(undef);
}

1;
