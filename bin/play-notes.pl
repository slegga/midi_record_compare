#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;

use Mojo::Base 'SH::ScriptX';
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
#use Carp::Always;
use Music::Tune;
use Mojo::File qw/path tempfile/;
use Carp::Always;

=head1 NAME

play-notes.pl

=head1 SYNOPSIS

play-notes.pl my-notefile.txt

=head1 DESCRIPTION

Play sounds from a given notefile.

('note_on', dtime, channel, note, velocity)
dtime = a value 0 to 268,435,455 (0x0FFFFFFF)
channel = a value 0 to 15
note = a value 0 to 127
velocity = a value 0 to 127

=head1 INSTALLATION

Prequeries:

sudo apt timidity

=cut


#,{return_uncatched_arguments => 1});
sub main {
    my $self = shift;
    my $note_file = $self->extra_options->[0] or die "Did not get a filename";
    die "File $note_file does not exists" if ! -e $note_file;

    my $tmpfile = tempfile(DIR=>'/tmp');
    my $tune = Music::Tune->from_string(path($note_file)->slurp);
    $tune->notes2score;
    my $cont = $tune->to_midi_file_content;
    path("$tmpfile")->spurt($cont);

    print `timidity $tmpfile`;
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main() if ! caller;
1;
