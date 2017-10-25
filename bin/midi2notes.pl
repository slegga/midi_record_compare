#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use lib '/media/data/perlbrew/perls/perl-5.26.0/lib/site_perl/5.26.0/';
use lib '/home/bruker/perl5/perlbrew/perls/perl-5.26.0/lib/site_perl/5.26.0/';

use Mojo::Base -strict;
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
#use Carp::Always;
use Model::Tune;


=head1 DESCRIPTION

('note_on', dtime, channel, note, velocity)
dtime = a value 0 to 268,435,455 (0x0FFFFFFF)
channel = a value 0 to 15
note = a value 0 to 127
velocity = a value 0 to 127

=cut

my $tune = Model::Tune->new(file=>$ARGV[0]);
$tune->data2events;
$tune->calc_shortest_note;
$tune->events2notes;
say "$tune";
