package Model::Input::ALSA;
use Mojo::Base 'Model::Input';
use MIDI::ALSA(':CONSTS');

=head1 NAME

Model::Input::ALSA

=head1 DESCRIPTION

"Input plugin" for Mojo::IOLoop for ALSA protocoll for reading .

inherits all methods from Model::Input and override following methods.

=cut

sub port {
    my $con =`aconnect -i`;
    (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0]
}

sub alsa_stream {
     my $r = IO::Handle->new;
     $r->fdopen(MIDI::ALSA::fd(),'r');
     warn $r->error if $r->error;
     return $r
 }

 sub init {
    my ($self) = @_;
         say "input port: ".$self->port();
         MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
         MIDI::ALSA::connectfrom( 0, $self->port, 0 );  # input port is lower (0)
}

sub register_events {
    my ($self,$loop, $master) = @_;
    $loop->recurring(0 => sub {
        my ($self) = shift;
        if (MIDI::ALSA::inputpending()) {
            $self->emit('alsaread', $master) ;
        }
    });
    $loop->on( alsaread => sub {
        $self->alsa_read(@_)
    });

}

sub alsa_read {
    my ($self,$loop,$master) = @_;
    my $on_time = Time::HiRes::time;

    # reset timer
    $master->silence_timer(0);

    my @alsaevent = MIDI::ALSA::input();
    return if $alsaevent[0] == 10; #ignore pedal
    return if $alsaevent[0] == 42; #ignore system beat
    $master->action->tune_starttime($on_time) if ! $master->action->tune_starttime();
    push @alsaevent,{dtime_sec=>
    	($on_time - ($master->action->last_event_starttime||$master->action->tune_starttime))};
    my $place = 'start';
    $place = 'slutt' if $alsaevent[0] == 7 ;
    $place = 'slutt' if $alsaevent[0] == 6 && $alsaevent[7][2] == 0;

    printf("%-6s %s %3d %.3f\n",$place,Model::Utils::Scale::value2notename($master->action->tune->scale,$alsaevent[7][1]),$alsaevent[7][2],$alsaevent[8]{dtime_sec}) if $alsaevent[0] == 6 || $alsaevent[0] == 7;
    my $event = Model::Utils::alsaevent2midievent(@alsaevent);
    if (defined $event) {
        push @{ $master->action->midi_events }, $event;
        $master->action->last_event_starttime($on_time);
    }
}

1;