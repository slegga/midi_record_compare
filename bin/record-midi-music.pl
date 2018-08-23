#!/usr/bin/env perl
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use Time::HiRes;
use Mojo::JSON qw(encode_json);
use Mojo::JSON 'to_json';
use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use Model::Action;
use Model::Input::ALSA;
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
has loop  => sub { Mojo::IOLoop->singleton };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has silence_timer=> -1;
has input_object => sub { Model::Input::ALSA->new };
has commands => sub{[
    [[qw/h help/],     0, 'This help text', sub{$_[0]->do_help}],
    [[qw/l list/],     1, 'List saved tunes.', sub{$_[0]->action->do_endtune;			$_[0]->action->do_list($_[1])}],
    [[qw/p play/],     1, ' Play last tune. If none defaults to the not ended play.', sub{$_[0]->action->do_endtune; $_[0]->action->do_play($_[1])}],
    [[qw/s save/],     1, 'Save play to disk as notes.', sub{$_[0]->action->do_endtune;	$_[0]->action->do_save($_[1])}],
    [[qw/c comp/],     1, 'Compare last tune with given name. If not name then test with --comp argument', sub{   $_[0]->action->do_comp($_[1])}],
    [[qw/sm savemidi/],1, 'Save as midi file. Add .midi if not present in name.', sub{$_[0]->action->do_endtune;  $_[0]->action->do_save_midi($_[1])}],
    [[qw/q quit/],     1, 'End session.',sub{$_[0]->do_quit}],
    [[qw/defaults/],    1, 'Stop last tune and start on new.', sub{$_[0]->action->do_endtune()}],
]};
has action => sub {Model::Action->new};
my @COPY_ARGV = @ARGV;
my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'comp|c=s', 'Compare play with this blueprint' ],
{return_uncatched_arguments => 1});
@ARGV = @COPY_ARGV;

__PACKAGE__->new->main(@ARGV) if !caller;


sub main {
    my $self = shift;
    if (! defined $self->input_object->port()) {
        if ((! exists $ENV{MOJO_MODE} || $ENV{MOJO_MODE} eq 'dry-run' ) && ! grep {'--dry-run' eq $_} @_) {
            printf '%s ## %s', ($ENV{MOJO_MODE}//'__UNDEF__'),join(',',@_);
            die "Did not find the midi input stream! Need port number.";
        }
    } else {
        $self->input_object->init();
    }

    $self->action->init; #load blueprints

    $self->input_object->register_events($self->loop, $self);
    $self->loop->recurring(1 => sub {
    	# not active
    	return if $self->silence_timer == -1;
    	my $t = Time::HiRes::time;
    	if (! $self->silence_timer ) {
    		$self->silence_timer($t);
    	} elsif ($t - $self->silence_timer >= 3) {
    		$self->stdin_read();
    	}
    });

    $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });

    $self->stdin_loop->start;
    $self->loop->start unless $self->loop->is_running;

}

=head2 register_midi_event

Takes score as arrays ref and extra if any as hash ref.

 score:
 ('note_on', dtime, channel, note, velocity)
 ['note_on', 0, 0, 96, 25],


Saves as score in self->midi_events

=cut

sub register_midi_event {
    my ($self, $event) = @_;
    return if ! defined $event;
    # my $place = 'start';
    # $place = 'slutt' if $alsaevent[0] == 7 ;
    # $place = 'slutt' if $alsaevent[0] == 6 && $alsaevent[7][2] == 0;

    printf("%-8s %-3s %3d %.3f\n",$event->[0]
    ,(defined($event->[3]) ? Model::Utils::Scale::value2notename($self->action->tune->scale,$event->[3]):'__UNDEF__')
    ,($event->[4]//0),
    $event->[2]//0);
    if ($event->[0] eq 'port_unsubscribed') { # piano is turned off.
        $self->action->do_endtune;
        say 'Forced quit';
        $self->do_quit;
        return;
    }
    if (defined $event && grep { $event->[0] eq $_ } qw/note_on note_off/) {
        push @{ $self->action->midi_events }, $event;
    }

}

# Read note pressed.

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
#    if (defined $cmd && grep { $cmd eq $_ } ('h','help')) {
#        $self->print_help();
#    } else {
	if(!defined $cmd) {
		if ($opts->comp) {
		$self->action->do_comp($opts->comp);
		} else {
		$self->action->do_endtune();
		}
	} else {
		for my $c(@{$self->commands}) {
		if (grep {$cmd eq $_} @{$c->[0]} ) {
		$c->[3]->($self, $name);
		last;
		}
		}
	}

#        }
#        } elsif (grep {$cmd eq $_} 'q','quit' ) {
#        	$self->do_quit;
#        } elsif (grep {$cmd eq $_} ('c','comp')) {
#            $self->action->do_comp($name);
#        } else {
#            $self->action->do_endtune;
#            if (grep { $cmd eq $_ } ('s','save')) {
#                $self->action->do_save($name);
#            } elsif (grep { $cmd eq $_} ('sm','savemidi')) {
#                $self->action->do_save_midi($name);
#            } elsif (grep { $cmd eq $_} ('p','play')) {
#                $self->action->do_play($name);
#            } elsif (grep {$cmd eq $_} ('l','list')) {
#                $self->action->do_list($name);
#            }
    #    }
        $self->action->midi_events([]); # clear history
        $self->input_object->reset_time();
   # }
}

sub print_help {
	my $self = shift;
	for my $cmd(@{$self->commands}) {
		printf "         %-16s %-10s  %-20s\n",join(',',@{$cmd->[0]}), ' [STR]'x$cmd->[1], $cmd->[2];
	}
}

sub do_quit {
	my ($self,$stream,$bytes) =@_;
	say "Goodbye";
	$self->loop->stop_gracefully;
}
1;
