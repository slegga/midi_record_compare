#!/usr/bin/env perl
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use MIDI::ALSA(':CONSTS');
use Time::HiRes;
use Mojo::JSON qw(encode_json);
use Mojo::File 'tempfile';
use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use Model::Utils;
use Model::Tune;
use SH::Script qw/options_and_usage/;

=head1 NAME

record-midi-music.pl

=head1 DESCRIPTION

Read midi signal from a USB-cable.

=head1 INSTALL GUIDE

 sudo apt install libasound2-dev
 sudo apt-get install timidity timidity-interfaces-extra
 cpanm MIDI::ALSA

=head1 USAGE

Type h + [enter]

=cut


has loop  => sub { Mojo::IOLoop->singleton };
has alsa_port => sub {my $con =`aconnect -i`;
    (map{/(\d+)/} grep {$_=~/client \d+.+\Wmidi/i} grep {$_!~/\sThrough/} split(/\n/, $con))[0]};
# has alsa_stream => sub {
#     my $r = IO::Handle->new;
#     $r->fdopen(MIDI::ALSA::fd(),'r');
#     warn $r->error if $r->error;
#     return $r
# };
has tune_starttime => 0;
has denominator =>8;
#has alsa_loop  => sub { my $self=shift;Mojo::IOLoop->new($self->alsa_stream)->timeout(0) };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has tune => sub {Model::Tune->new};
has midi_score => sub {[]};
has shortest_note_time => 12
;

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'facit|f=s', 'Set default facit when compering' ],
,{return_uncatched_arguments => 1});


__PACKAGE__->new->main;

sub main {
    my $self = shift;
    die "Did not find the midi input stream! Need port number." if ! defined $self->alsa_port;
    say $self->alsa_port;
    MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
    MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)
    # say dumper $self->alsa_stream;

    #  $self->alsa_loop->on( read => sub { $self->alsa_read(@_)  });
    Mojo::IOLoop->recurring(0 => sub {
        my $self = shift;
        $self->emit('alsaread') if MIDI::ALSA::inputpending();
    });
    #  $self->alsa_loop->on( read => sub { $self->alsa_read(@_)  });
    Mojo::IOLoop->( alsaread => sub { $self->alsa_read(@_)  });
    Mojo::IOLoop->start;
    if (1) {
    # $self->loop->start unless $self->loop->is_running;
    $self->stdin_loop->on(read => sub { $self->stdin_read(@_) });
    $self->stdin_loop->start;
    }
    $self->loop->start unless $self->loop->is_running;

}

# Read note pressed.
sub alsa_read {
    my ($self, $stream, $bytes) = @_;
    #say "hey".MIDI::ALSA::inputpending();
    my $on_time = Time::HiRes::time;
    my @alsaevent = MIDI::ALSA::input();
    my $off_time = Time::HiRes::time;
    $self->tune_starttime($on_time) if ! $self->tune_starttime();
    push @alsaevent,{starttime=>($on_time - $self->tune_starttime()), duration=>($off_time - $on_time)};
    printf "Alsa event: %s\n", encode_json(\@alsaevent);
    my $score_n = Model::Utils::alsaevent2scorenote(@alsaevent);
    if (defined $score_n) {
        push @{ $self->midi_score }, $score_n;
        say Model::Note->from_score($score_n
        , {shortest_note_time=>($self->shortest_note_time || 48 )
            , denominator=>($self->denominator||8)
            , tune_starttime=>$self->tune_starttime
        })->to_string;
    }
}

# Stop existing tune
# analyze
# print
sub stdin_read {
    my ($self, $stream, $bytes) = @_;
    say "Got input!";
    chomp $bytes;
    my ($cmd, $name)=split /\s+/, $bytes;
    if (grep { $cmd eq $_ } ('h','help')) {
        $self->print_help();
    } else {
        if ( @{$self->midi_score} > 8 ) {
            $self->tune(Model::Tune->from_midi_score($self->midi_score));
            $self->tune->calc_shortest_note;
            $self->tune->score2notes;
            print $self->tune->to_string;
            $self->shortest_note_time($self->tune->shortest_note_time);
            $self->denominator($self->tune->denominator);
            printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
        }
        if(!defined $cmd) {
        } elsif (grep { $cmd eq $_ } ('s','save')) {
            $self->do_save($name);
        } elsif (grep { $cmd eq $_} ('p','play')) {
            $self->do_play($name);
        } elsif (grep {$cmd eq $_} ('l','list')) {
            $self->do_list($name);
        } elsif (grep {$cmd eq $_} ('c','comp')) {
            $self->do_comp($name);
        }
        $self->midi_score([]); # clear history
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
    if (defined $name && -e $name) {
        $tune = Model::Tune->from_note_file($name);
        $tune->notes2score;
    } else {
        $tune = $self->tune;
    }
    $tune->to_midi_file("$tmpfile");
    print `timidity $tmpfile`;
}

sub do_list {
    my ($self, $name) = @_;
    ...;
}

sub do_comp {
    my ($self, $name) = @_;
    die "Missing self" if !$self;
    my $tune_play = $self->tune;
    my $tune_blueprint= Model::Tune->from_note_file($name||$opts->facit);
    $tune_play->evaluate_with_blueprint($tune_blueprint);
}
