package Model::Input::ALSA;
use Mojo::Base 'Model::Input';
use MIDI::ALSA(':CONSTS');

=head1 NAME

Model::Input::ALSA

=head1 DESCRIPTION

"Input plugin" for Mojo::IOLoop for ALSA protocoll for reading .

inherits all methods from Model::Input and override following methods.

[type, flags, tag, queue, time, source, destination, data] ALSA

=cut

=head2 ATTRIBUTES

=cut

has tune_starttime => 0;
has last_event_starttime => 0;


=head2 METHODS

=head2 port

Return port.

=cut



sub port {
    my $con =`aconnect -i`;
    (map{/(\d+)/} grep {$_=~/client \d+r.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0]
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
    return if $alsaevent[0] == 10; #ignore pedal
    return if $alsaevent[0] == 42; #ignore system beat
    $self->tune_starttime($on_time) if ! $self->tune_starttime();
    push @alsaevent,{dtime_sec=>
    	($on_time - ($self->last_event_starttime||$self->tune_starttime))};
#    my $place = 'start';
#    $place = 'slutt' if $alsaevent[0] == 7 ;
#    $place = 'slutt' if $alsaevent[0] == 6 && $alsaevent[7][2] == 0;

    #printf("%-6s %s %3d %.3f\n",$place,Model::Utils::Scale::value2notename($controller->action->tune->scale,$alsaevent[7][1]),$alsaevent[7][2],$alsaevent[8]{dtime_sec}) if $alsaevent[0] == 6 || $alsaevent[0] == 7;
    my $event = Model::Utils::alsaevent2midievent(@alsaevent);
    $self->last_event_starttime($on_time) if $event;
    $controller->register_midi_event($event);
}

sub reset_time {
    my ($self) = @_;
    $self->tune_starttime(undef);
}

1;
