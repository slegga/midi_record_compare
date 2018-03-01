#!/usr/bin/env perl
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use MIDI::ALSA(':CONSTS');
use Time::HiRes;
use Mojo::JSON qw(encode_json);
use Mojo::File qw(tempfile path);
use Mojo::JSON 'to_json';
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use Model::Utils;
use Model::Tune;
use SH::Script qw/options_and_usage/;
use Carp::Always;
#use Carp::Always;

=head1 NAME

record-midi-music.pl

=head1 DESCRIPTION

Read midi signal from a USB-cable.

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
has tune_starttime => 0;
has last_event_starttime => 0;
has silence_timer=> -1;
has denominator =>8;
has loop  => sub { Mojo::IOLoop->singleton };
#sub { my $self=shift;Mojo::IOLoop::Stream->new($self->alsa_stream)->timeout(0) };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has tune => sub {Model::Tune->new};
has midi_events => sub {[]};
has shortest_note_time => 12;
has blueprints_dir => sub {path("$FindBin::Bin/../blueprints")};

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
#   		warn "Timeout";

    	my $t = Time::HiRes::time;
    	if (! $self->silence_timer ) {
    		$self->silence_timer($t);
    	} elsif ($t - $self->silence_timer >= 2) {
    	#	warn "Timeout";
    		$self->stdin_read();
    	}
#    	print STDERR "Delay: "
    });

    $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });
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
#    my $off_time = Time::HiRes::time;
    $self->tune_starttime($on_time) if ! $self->tune_starttime();
    push @alsaevent,{dtime_sec=>
    	($on_time - ($self->last_event_starttime||$self->tune_starttime))};
    #printf "Alsa event: %s\n", encode_json(\@alsaevent);
    my $event = Model::Utils::alsaevent2midievent(@alsaevent);
    if (defined $event) {
        push @{ $self->midi_events }, $event;
        $self->last_event_starttime($on_time);
        say to_json($event);
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
                $self->do_comp($opts->comp);
            } else {
                $self->do_endtune();
            }
        }elsif (grep {$cmd eq $_} 'q','quit' ) {
        	$self->do_quit;
        } elsif (grep {$cmd eq $_} ('c','comp')) {
            $self->do_comp($name);
        } else {
            $self->do_endtune;
            if (grep { $cmd eq $_ } ('s','save')) {
                $self->do_save($name);
            } elsif (grep { $cmd eq $_} ('p','play')) {
                $self->do_play($name);
            } elsif (grep {$cmd eq $_} ('l','list')) {
                $self->do_list($name);
            }
        }
        $self->midi_events([]); # clear history
        $self->tune_starttime(undef);
    }
}

sub print_help {
    print q'
    h,help          This help text
    s,save [NAME]   Save play to disk as notes.
    p,play [NAME]   Play last tune. If none defaults to the not ended play.
    l,list [REGEXP] List saved tunes.
    c,comp [NAME]   Compare last tune with given name. If not name then test with --comp argument
    q,quit			End session.
    defaults        Stop last tune and start on new.

';
}

sub do_endtune {
    my ($self) = @_;
    return if (@{$self->midi_events}<8);
    my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
    $self->tune(Model::Tune->from_midi_score($score));
    $self->tune->calc_shortest_note;
    $self->tune->score2notes;
    print $self->tune->to_string;
    $self->shortest_note_time($self->tune->shortest_note_time);
    $self->denominator($self->tune->denominator);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
    return $self;
}

sub do_save {
    my ($self, $name) = @_;
    $self->tune->to_note_file($self->local_dir($self->blueprints_dir->sibling('notes'))->child($name));
}

sub do_play {
    my ($self, $name) = @_;
    my $tmpfile = tempfile(DIR=>'/tmp');
    my $tune;
    if (defined $name) {
        if (-e $name) {
            $tune = Model::Tune->from_note_file($name);
            $tune->notes2score;
        } else {
        	my $tmp = $self->blueprints_dir->child($name);
        	if( -e $tmp) {
	            $tune = Model::Tune->from_note_file($tmp);
	            $tune->notes2score;
	        } else {
	 			$tmp = $self->blueprints_dir->sibling('local','notes')->child($name);
	 			if (-e $tmp) {
		            $tune = Model::Tune->from_note_file($tmp);
		 	        $tune->notes2score;
		 	    } else {
	 				$tmp = $self->blueprints_dir->sibling('local','blueprints')->child($name);
    	 			if (-e $tmp) {
    		            $tune = Model::Tune->from_note_file($tmp);
    		 	        $tune->notes2score;
    		 	    } else {
    		 	    	warn "Did not find $name. Play stored tune instead.";
			            $tune = $self->tune;
    		 	    }
				}
			}
        }
    } else {
        $tune = $self->tune;
    }
    $tune->to_midi_file("$tmpfile");
    print `timidity $tmpfile`;
}

sub do_list {
    my ($self, $name) = @_;
    say '';
    say "notes/";
    my $notes_dir = path("$FindBin::Bin/../notes");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");

    say '';
    say "blueprints/";
    say $self->blueprints_dir->list_tree->map(sub{basename($_)})->join("\n");
}

sub do_comp {
    my ($self, $name) = @_;
    say "compare $name";
    die "Missing self" if !$self;

    return if ! $name;
    if  ( @{$self->midi_events } < 8 ) {
        warn "Less than 8 notes. No tune is that short";
    }

    my $filename = $name;
    if (! -e $filename) {
	    my $bluedir = $self->blueprints_dir->to_string;
        say $bluedir;
        if ( -e $self->blueprints_dir->child($filename)) {
	        $filename = $self->blueprints_dir->child($filename);
        } else {
        	my $lbf = $self->local_dir($self->blueprints_dir);
        	if (-e $lbf) {
        		$filename = $lbf;
        	} else {
	            warn "$filename or ".$self->blueprints_dir->child($filename)." or $lbf not found";
    	        return;
    	    }
        }
	}
    my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
    $self->tune(Model::Tune->from_midi_score($score));
    my $tune_blueprint= Model::Tune->from_note_file($filename);
    $self->tune->denominator($tune_blueprint->denominator);

    $self->tune->calc_shortest_note;

    $self->tune->score2notes;

   	my $play_bs = $self->tune->get_beat_sum;
   	my $blueprint_bs = $tune_blueprint->get_beat_sum;
   	if ($play_bs*1.5 <$blueprint_bs || $play_bs > 1.5*$blueprint_bs) {
        $self->tune->beat_score($self->tune->beat_score/2) ;
        $self->shortest_note_time($self->shortest_note_time * $play_bs / $blueprint_bs);
	    $self->tune->score2notes;
    }

    $self->denominator($self->tune->denominator);

#    print $self->tune->to_string;
    $self->shortest_note_time($self->tune->shortest_note_time);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
    $self->tune->evaluate_with_blueprint($tune_blueprint);
    return $self;
}


sub do_quit {
	my ($self,$stream,$bytes) =@_;
	say "Goodbye";
	$self->loop->stop_gracefully;
}

sub local_dir {
	my ($self, $mojofiledir) =@_;
	my @l = @$mojofiledir;
	splice(@l,$#$mojofiledir-1,0,'local');
	return path(@l);
}
1;
