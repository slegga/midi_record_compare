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
has last_event_starttime =>0;
has denominator =>8;
has alsa_loop  => sub { Mojo::IOLoop->singleton };
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


__PACKAGE__->new->main;

sub main {
    my $self = shift;
    die "Did not find the midi input stream! Need port number." if ! defined $self->alsa_port;
    say "alsa port: ".$self->alsa_port;
    MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
    MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)

    #$self->alsa_loop->on( read => sub { $self->alsa_read(@_)  });
    $self->alsa_loop->recurring(0 => sub {
        my ($self) = shift;
        if (MIDI::ALSA::inputpending()) {
#            say "HAI";
            $self->emit('alsaread',$self) ;
        }
    });
    $self->alsa_loop->on( alsaread => sub {
        $self->alsa_read(@_)
#    say "Yo";
});
    #$self->alsa_loop->start;
    if (1) {
    # $self->loop->start unless $self->loop->is_running;
    $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });
    $self->stdin_loop->start;
    }
    $self->loop->start unless $self->loop->is_running;

}

# Read note pressed.
sub alsa_read {
    my ($self) = @_;
    my $on_time = Time::HiRes::time;
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
        #say Model::Note->from_score($score_n
        #, {shortest_note_time=>($self->shortest_note_time || 48 )
    #        , denominator=>($self->denominator||8)
    #        , tune_starttime=>$self->tune_starttime
    #    })->to_string;
    }
}

# Stop existing tune
# analyze
# print
sub stdin_read {
    my ($self, $stream, $bytes) = @_;
    chomp $bytes;
    my ($cmd, $name)=split /\s+/, $bytes;
    if (defined $cmd && grep { $cmd eq $_ } ('h','help')) {
        $self->print_help();
    } else {
        if(!defined $cmd) {
            if ($opts->facit) {
                $self->do_comp($opts->facit);
            }
        } elsif (grep {$cmd eq $_} ('c','comp')) {
            $self->do_comp($name);
        } else {
            if ( @{$self->midi_events } > 8 ) {
                my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
                $self->tune(Model::Tune->from_midi_score($score));
                $self->tune->calc_shortest_note;
                $self->tune->score2notes;
                print $self->tune->to_string;
                $self->shortest_note_time($self->tune->shortest_note_time);
                $self->denominator($self->tune->denominator);
                printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
            }

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
    c,comp [NAME]   Compare last tune with given name. If not name then test with ARGV[0]
    defaults        Stop last tune and start on new.
';
}

sub do_save {
    my ($self, $name) = @_;
    $self->tune->to_note_file($name);
}

sub do_play {
    my ($self, $name) = @_;
    my $tmpfile = tempfile(DIR=>'/tmp');
    my $tune;
    if (defined $name) {
        if (-e $name) {
            $tune = Model::Tune->from_note_file($name);
            $tune->notes2score;
        } elsif( -e $self->blueprints_dir->child($name)) {
            ...;
        } else {
            $tune = $self->tune;
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
    say '';
    say "blueprints/";
    say $self->blueprints_dir->list_tree->map(sub{basename($_)})->join("\n");
}

sub do_comp {
    my ($self, $name) = @_;
    die "Missing self" if !$self;

    return if ! $name;
    return if  ( @{$self->midi_events } < 8 );

    my $filename = $name;
    if (! -e $filename) {
	    my $bluedir = $self->blueprints_dir->to_string;
        say $bluedir;
        if (! -e $self->blueprints_dir->child($filename)) {
            warn "$filename or ".$self->blueprints_dir->child($filename)." not found";
            return;
        }
        $filename = $self->blueprints_dir->child($filename);
	}
    my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
    $self->tune(Model::Tune->from_midi_score($score));
    my $tune_blueprint= Model::Tune->from_note_file($filename);
    $self->tune->denominator($tune_blueprint->denominator);

    $self->tune->calc_shortest_note;

    $self->tune->score2notes;
    $self->denominator($self->tune->denominator);

#    print $self->tune->to_string;
    $self->shortest_note_time($self->tune->shortest_note_time);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
    $self->tune->evaluate_with_blueprint($tune_blueprint);
}
