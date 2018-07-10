#!/usr/bin/env perl
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use MIDI;
use MIDI::ALSA(':CONSTS');
use Time::HiRes;
use Mojo::JSON qw(encode_json);
use Mojo::JSON 'to_json';
use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use Model::Action;
use SH::Script qw/options_and_usage/;
use Carp::Always;
use Term::ANSIColor;
use feature 'unicode_strings';
use utf8;
binmode(STDOUT, ":utf8");
use open ':encoding(UTF-8)';

#use Carp::Always;

=head1 NAME

record-midi-music.pl

=head1 DESCRIPTION

Read midi signal from a USB-cable.

Present a cli User Interface and send request to Model::Action;

=head1 INSTALL GUIDE

 sudo apt install libasound2-dev
 sudo apt-get install timidity timidity-interfaces-extra
 cpanm MIDI::ALSA
 cpanm Mojolicious

=head1 USAGE

Type h + [enter]

=cut


has loop  => sub { Mojo::IOLoop->singleton };
has alsa_port => sub {my $con =`aconnect -i`;
    (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0]};
has alsa_stream => sub {
     my $r = IO::Handle->new;
     $r->fdopen(MIDI::ALSA::fd(),'r');
     warn $r->error if $r->error;
     return $r
 };
has loop  => sub { Mojo::IOLoop->singleton };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has silence_timer=> -1;

has action => sub {Model::Action->new};
my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'comp|c=s', 'Compare play with this blueprint' ],
,{return_uncatched_arguments => 1});


__PACKAGE__->new->main if !caller;


sub main {
    my $self = shift;
    if (! defined $self->alsa_port
        && (! exists $ENV{MOJO_MODE} || $ENV{MOJO_MODE} ne 'dry-run')) {
            die "Did not find the midi input stream! Need port number.";
    } else {
        say "alsa port: ".$self->alsa_port;
        MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
        MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)
    }

    $self->action->init; #load blueprints

    $self->loop->recurring(0 => sub {
        my ($self) = shift;
        if (MIDI::ALSA::inputpending()) {
            $self->emit('alsaread',$self) ;
        }
    });
    $self->loop->on( alsaread => sub {
        $self->alsa_read(@_)
	});
    $self->loop->recurring(1 => sub {
    	# not active
    	return if $self->silence_timer == -1;
    	my $t = Time::HiRes::time;
    	if (! $self->silence_timer ) {
    		$self->silence_timer($t);
    	} elsif ($t - $self->silence_timer >= 4) {
    		$self->stdin_read();
    	}
    });

    $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });

    MIDI::ALSA::start() or die "start failed";
    $self->stdin_loop->start;
    $self->loop->start unless $self->loop->is_running;

}

# Read note pressed.
sub alsa_read {
    my ($self) = @_;
    my $on_time = Time::HiRes::time;

    # reset timer
    $self->silence_timer(0);

    my @alsaevent = MIDI::ALSA::input();
    return if $alsaevent[0] == 10; #ignore pedal
    return if $alsaevent[0] == 42; #ignore system beat
    $self->action->tune_starttime($on_time) if ! $self->action->tune_starttime();
    push @alsaevent,{dtime_sec=>
    	($on_time - ($self->action->last_event_starttime||$self->action->tune_starttime))};
    my $place = 'start';
    $place = 'slutt' if $alsaevent[0] == 7 ;
    $place = 'slutt' if $alsaevent[0] == 6 && $alsaevent[7][2] == 0;

    printf("%-6s %s %3d %.3f\n",$place,Model::Utils::Scale::value2notename($self->action->tune->scale,$alsaevent[7][1]),$alsaevent[7][2],$alsaevent[8]{dtime_sec}) if $alsaevent[0] == 6 || $alsaevent[0] == 7;
    my $event = Model::Utils::alsaevent2midievent(@alsaevent);
    if (defined $event) {
        push @{ $self->action->midi_events }, $event;
        $self->action->last_event_starttime($on_time);
    }
}

# Stop existing tune
# analyze
# print
sub stdin_read {
    my ($self, $stream, $bytes) = @_;
    my ($cmd, $name);
    if (defined $bytes) {
        say $bytes ;
        chomp $bytes;
        ($cmd, $name)=split /\s+/, $bytes;
    }
    $self->silence_timer(-1);
    if (defined $cmd && grep { $cmd eq $_ } ('h','help')) {
        $self->print_help();
    } else {
        if(!defined $cmd) {
            if ($opts->comp) {
                $self->action->do_comp($opts->comp);
            } else {
                $self->action->do_endtune();
            }
        }elsif (grep {$cmd eq $_} 'q','quit' ) {
        	$self->do_quit;
        } elsif (grep {$cmd eq $_} ('c','comp')) {
            $self->action->do_comp($name);
        } else {
            $self->action->do_endtune;
            if (grep { $cmd eq $_ } ('s','save')) {
                $self->action->do_save($name);
            } elsif (grep { $cmd eq $_} ('sm','savemidi')) {
                $self->action->do_save_midi($name);
            } elsif (grep { $cmd eq $_} ('p','play')) {
                $self->action->do_play($name);
            } elsif (grep {$cmd eq $_} ('l','list')) {
                $self->action->do_list($name);
            }
        }
        $self->action->midi_events([]); # clear history
        $self->action->tune_starttime(undef);
    }
}

sub print_help {
    print q'
    h,help          This help text
    s,save [NAME]   Save play to disk as notes.
    p,play [NAME]   Play last tune. If none defaults to the not ended play.
    l,list [REGEXP] List saved tunes.
    c,comp [NAME]   Compare last tune with given name. If not name then test with --comp argument
    sm [NAME]       Save as midi file. Add .midi if not present in name.
    q,quit			End session.

    defaults        Stop last tune and start on new.

';
}

sub do_quit {
	my ($self,$stream,$bytes) =@_;
	say "Goodbye";
	$self->loop->stop_gracefully;
}


1;
