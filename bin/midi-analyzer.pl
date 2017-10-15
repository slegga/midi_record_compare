#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib '/media/data/perlbrew/perls/perl-5.26.0/lib/site_perl/5.26.0/';
use Mojo::Base -strict;
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
use SH::PrettyPrint;

=head1 DESCRIPTION

('note_on', dtime, channel, note, velocity)
dtime = a value 0 to 268,435,455 (0x0FFFFFFF)
channel = a value 0 to 15
note = a value 0 to 127
velocity = a value 0 to 127

=cut
foreach my $one (@ARGV) {
    my $opus = MIDI::Opus->new({ 'from_file' => $one, 'no_parse' => 1 });
    my @tracks = $opus->tracks;
    print "$one has ", scalar( @tracks ). " tracks\n";
    my $data = $tracks[0]->data;
    my @events = MIDI::Event::decode( \$data, {exclude=>['control_change','set_tempo','sysex_f0'] } );
#   print Dumper @tracks;
    say ref $events[0] ;
    SH::PrettyPrint::print_arrayofarrays $_ for @events;
#    print Dumper @events;
# print     $opus->dump( { flat=>1} );
   print Dumper  \%MIDI::number2note;
}
exit;
