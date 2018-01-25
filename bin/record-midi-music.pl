#!/usr/bin/env perl
use Mojo::Base '-base';
use Model::Tune;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Util 'dumper';
use Mojo::Loader 'data_section';
use MIDI::ALSA(':CONSTS');
use Model::Utils;
use Time::HiRes;
use Mojo::JSON qw(encode_json);


=head1 NAME

=head1 DESCRIPTION

=head1 INSTALL GUIDE

sudo apt install libasound2-dev

cpanm MIDI::ALSA

=cut

has file_count => 0;
has file  => sub { shift->file_start('0_START.pgm') };
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
has alsa_loop  => sub { my $self=shift;Mojo::IOLoop::Stream->new($self->alsa_stream)->timeout(0) };
has stdin_loop => sub { Mojo::IOLoop::Stream->new(\*STDIN)->timeout(0) };
has tune => sub {Model::Tune->new};
has midi_score => sub {[]};

__PACKAGE__->new->main;

sub main {
  my $self = shift;
  say $self->alsa_port;
  die "Did not find the midi input stream! Need port number." if ! defined $self->alsa_port;
  MIDI::ALSA::client( 'Perl MIDI::ALSA client', 1, 1, 0 );
  MIDI::ALSA::connectfrom( 0, $self->alsa_port, 0 );  # input port is lower (0)
  # say dumper $self->alsa_stream;

  $self->alsa_loop->on( read => sub { $self->alsa_read(@_)  });
  $self->alsa_loop->start;
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
    say "hey".MIDI::ALSA::inputpending();
    my $on_time = Time::HiRes::time;
    my @alsaevent = MIDI::ALSA::input();
    my $off_time = Time::HiRes::time;
    print "Alsa event: " . dumper(\@alsaevent);
    $self->tune_starttime($on_time) if ! $self->tune_starttime;
    my $score_n = Model::Utils::alsaevent2scorenote(@alsaevent,
    {starttime=>(Time::HiRes::time - $on_time), duration=>($off_time - $on_time)});
    if (defined $score_n) {
        push @{ $self->midi_score }, $score_n;
        say encode_json($score_n);
    }
}

# Stop existing tune
# analyze
# print
sub stdin_read {
    my ($self, $stream, $bytes) = @_;
    say "Got input!";
    $self->tune = Model::Tune->from_midi_score($self->score);
    $self->tune->calc_shortest_note;
    $self->tune->score2notes;
    print $self->tune->to_string;
	$self->midi_score([]); # clear history
    $self->tune_starttime(undef);

}
