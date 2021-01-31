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
use Music::Blueprints;
use Music::BlueprintsExt;
use Music::Input::ALSA;
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Carp::Always;
use Term::ANSIColor;
use feature 'unicode_strings';
use utf8;
# binmode(STDIN, ":utf8");
binmode(STDOUT, ":encoding(UTF-8)");
use open ':encoding(UTF-8)';
use IO::Handle;
STDOUT->autoflush(1);

#use Carp::Always;

=head1 NAME

record-midi-music.pl

=head1 DESCRIPTION

Read midi signal from a USB-cable.

Present a cli User Interface and send request to Music::Action;

=head1 INSTALL GUIDE

 sudo apt install libasound2-dev
 sudo apt-get install timidity timidity-interfaces-extra
 cpanm MIDI::ALSA
 cpanm Mojolicious

=head1 USAGE

Type h + [enter]

=cut


has loop  => sub { Mojo::IOLoop->singleton };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has silence_timer=> -1;
has piano_keys_pressed =>sub{ {} };
has input_object => sub { Music::Input::ALSA->new };
has prev_controller => sub { {} };
has 'hand';
has commands => sub{[
    [[qw/h help/],     0, 'This help text', sub{$_[0]->print_help}],
    [[qw/l list/],     1, 'List saved tunes.', sub{
        my $self =$_[0]; $self->finish;$self->blueprints->do_list($_[1])}],
    [[qw/p play/],     1, ' Play last played tune.', sub{my $self =$_[0]; $self->finish; $self->tune->play}],
    [[qw/pb playblueprint/],     1, ' Play
    ared blueprint. If none play none.', sub{
        my ($self, $name) = @ _;
        my $filepath;
        if ($name) {
            $filepath = $self->blueprints->get_pathfile_by_name($name);
        }
        elsif ($self->comp_working) {
            $filepath = $self->comp_working;
        } else {
            print STDERR "Notting to play. I do not know what to do\n";
            return;
        }
        my $t =$self->blueprints->get_blueprint_by_pathfile($filepath);
        $t->play;
    }],
    [[qw/s save/],     1, 'Save play to disk as notes.', sub{
        say "save action $_[1]";
        my $t = $_[0]->tune;	$_[0]->blueprints->do_save($t, $_[1])}],
    [[qw/c comp/],     0, 'Compare last tune with given name. If not name then test with --comp argument. 0=reset', sub{
        my ($self, $name)=@_;
        if (! $name) {
            $self->comp_working(undef);
            say "Reset blueprint";
        } else {
            my $filename = $self->blueprints->get_pathfile_by_name($name);
            $self->comp_working($filename);
        	$self->blueprints->do_comp($self->tune,$filename,$self->hand);
        }
    }],
    [[qw /ha hand/],    1, 'Bluenotes with only one hand. Valid values are left,right and both',sub {$_[0]->hand($_[1])}],
    [[qw/sm savemidi/],1, 'Save as midi file. Add .midi if not present in name.', sub{$_[0]->finish;  $_[0]->blueprints->do_save_midi($_[1])}],
    [[qw/q quit/],     0, 'End session.',sub{$_[0]->do_quit}],
    [[qw/defaults/],   0, 'Stop last tune and start on new.', sub {
    }]
]};
has blueprints => sub {
    my $self = shift;
    if ($self->api) {
        Music::BlueprintsExt->new
    } else {
        Music::Blueprints->new;
    }
    };
has tune => sub {Music::Tune->new};
has 'comp_working';
has 'finished'; #tune is finished and can be
option  'comp=s', 'Compare play with this blueprint';
option  'dryrun!',  'Do not expect a linked piano';
option  'debug!',   'Print debug info';
option 'api!',  'Get blueprints from API';
option 'breaklength=i', 'Set length in seconds before program execute a end tune command Default: 5', { default => 5};


sub main {
    my $self = shift;
    if ( $self->dryrun ) {
		printf '%s ## %s', ($ENV{MOJO_MODE}//'__UNDEF__'),join(',',@_);
    } else {
    	$self->input_object->port();
    	$self->input_object->init();
    }
    $self->comp_working=$self->comp if $self->comp;
    $self->blueprints->init; #load blueprints

    $self->input_object->register_events( $self->loop, $self );
    $self->loop->recurring( 1 => sub {
    	# not active
    	return if $self->silence_timer == -1;
    	my $t = Time::HiRes::time;
    	if ( ! $self->silence_timer ) {
    		$self->silence_timer($t);
    	}
    	elsif ( $t - $self->silence_timer >= $self->breaklength && ! keys %{ $self->piano_keys_pressed }) {
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
    if ($self->finished) {
        $self->restart;
    }
	#if ($self->debug) {
    if ($event->[0] eq 'control_change') {
        my $crl = $self->prev_controller;
        if (($crl->{$event->[3]} && ! $event->[4])
        or  (! $crl->{$event->[3]} && $event->[4])
        )
        {
            $crl->{$event->[3]} = $event->[4];
            print  join('  ', grep {defined } @$event)."\r";

            #end tune if left pedal pressed
            if ($event->[3] == 67 && $event->[4]) {
        		    $self->finish_and_compare;
                return;
            }
            $self->prev_controller($crl);
        }
    } else    {
	    printf("%-8s %-3s %3d %.3f %5d",$event->[0]
	    ,(defined($event->[3]) ? Music::Utils::Scale::value2notename($self->tune->scale,$event->[3]):'__UNDEF__')
	    ,($event->[4]//0),
	    ($event->[2]//0),
	    ($event->[1]//0)
	    );
	    print "\r";
    }
	#}
    if ($event->[0] eq 'port_unsubscribed') { # piano is turned off.
        $self->finish_and_compare;
        say 'Forced quit';
        $self->do_quit;
        return;
    }
    if (defined $event && grep { $event->[0] eq $_ } qw/note_on note_off/) {
        push @{ $self->tune->in_midi_events }, $event;
        my $pks = $self->piano_keys_pressed;
        my $pkp = $self->piano_keys_pressed;
        if ($event->[0] eq 'note_on') {
        	$pkp->{$event->[3]} =1;
        } elsif($event->[0] eq 'note_off') {
        	delete $pkp->{$event->[3]};
        }
        $self->piano_keys_pressed($pkp);
    } else {
    	to_json($event);
    }

}

# make ready for a new emtpy tune
sub restart {
    my $self = shift;
    $self->tune(Music::Tune->new); # clear history
    $self->input_object->reset_time();
    $self->finished(0);
    return $self;
}

#finish mark tune as ended

sub finish {
    my $self = shift;
    $self->tune($self->tune->finish);
    $self->finished(1);
    return $self;
}


sub finish_and_compare {
    my ($self) = @_;
    $self->finish;
    my $guess;
    $guess = $self->comp_woriking || $self->blueprints->guess_blueprint($self->tune);
    $self->blueprints->do_comp($self->tune, $guess,$self->hand);
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
    if (! defined $self->comp_working && defined $self->comp) {
        $self->comp_working($self->comp);
    }
	if(!defined $cmd) {
        $self->finish_and_compare;
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
