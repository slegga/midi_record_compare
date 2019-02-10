#!/usr/bin/env perl

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
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Carp::Always;
use Term::ANSIColor;
use feature 'unicode_strings';
use utf8;
# binmode(STDIN, ":utf8");
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
has piano_keys_pressed =>sub{ {} };
has input_object => sub { Model::Input::ALSA->new };
has commands => sub{[
    [[qw/h help/],     0, 'This help text', sub{$_[0]->print_help}],
    [[qw/l list/],     1, 'List saved tunes.', sub{$_[0]->action->do_endtune;			$_[0]->action->do_list($_[1])}],
    [[qw/p play/],     1, ' Play last tune. If none defaults to the not ended play.', sub{$_[0]->action->do_endtune; $_[0]->action->do_play($_[1])}],
    [[qw/s save/],     1, 'Save play to disk as notes.', sub{$_[0]->action->do_endtune;	$_[0]->action->do_save($_[1])}],
    [[qw/c comp/],     0, 'Compare last tune with given name. If not name then test with --comp argument', sub{   $_[0]->action->do_comp($_[1])}],
    [[qw/sm savemidi/],1, 'Save as midi file. Add .midi if not present in name.', sub{$_[0]->action->do_endtune;  $_[0]->action->do_save_midi($_[1])}],
    [[qw/q quit/],     0, 'End session.',sub{$_[0]->do_quit}],
    [[qw/defaults/],   0, 'Stop last tune and start on new.', sub{$_[0]->action->do_endtune()}],
]};
has action => sub {Model::Action->new};
option  'comp=s', 'Compare play with this blueprint';
option  'dryrun!',  'Do not expect a linked piano';
option  'debug!',   'Print debug info';



sub main {
    my $self = shift;
    if ( $self->dryrun ) {
		printf '%s ## %s', ($ENV{MOJO_MODE}//'__UNDEF__'),join(',',@_);
    } else {
    	$self->input_object->port();
    	$self->input_object->init();
    }

    $self->action->init; #load blueprints

    $self->input_object->register_events( $self->loop, $self );
    $self->loop->recurring( 1 => sub {
    	# not active
    	return if $self->silence_timer == -1;
    	my $t = Time::HiRes::time;
    	if ( ! $self->silence_timer ) {
    		$self->silence_timer($t);
    	}
    	elsif ( $t - $self->silence_timer >= 3 && ! keys %{ $self->piano_keys_pressed }) {
    		# do_endtune
    		$self->stdin_read();
    	}
    });

    $self->stdin_loop->on( read => sub { $self->stdin_read(@_) } );

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

	if ($self->debug) {
	    printf("%-8s %-3s %3d %.3f\n",$event->[0]
	    ,(defined($event->[3]) ? Model::Utils::Scale::value2notename($self->action->tune->scale,$event->[3]):'__UNDEF__')
	    ,($event->[4]//0),
	    $event->[2]//0);
	}
    if ($event->[0] eq 'port_unsubscribed') { # piano is turned off.
        $self->action->do_endtune;
        say 'Forced quit';
        $self->do_quit;
        return;
    }
    if (defined $event && grep { $event->[0] eq $_ } qw/note_on note_off/) {
        push @{ $self->action->midi_events }, $event;
        my $pks = $self->piano_keys_pressed;
        my $pkp = $self->piano_keys_pressed;
        if ($event->[0] eq 'note_on') {
        	$pkp->{$event->[3]} =1;
        } elsif($event->[0] eq 'note_off') {
        	delete $pkp->{$event->[3]};
        }
        $self->piano_keys_pressed($pkp);
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
	if(!defined $cmd) {
		if ($self->comp) {
			$self->action->do_comp($self->comp);
		} else {
			$self->action->do_endtune();
		}
	} else {
		for my $c(@{$self->commands}) {
			if (grep {$cmd eq $_} @{$c->[0]} ) {
				my $sub = $c->[3];
				if (! $sub) {
					say "cmd $cmd";
					p $c;
					die "invalid option def";
				}
				say "cmd $cmd";
				$sub->($self, $name );
				last;
			}
		}
	}

    $self->action->midi_events([]); # clear history
    $self->input_object->reset_time();
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

__PACKAGE__->new->main();

