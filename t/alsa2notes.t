use Mojo::Base -strict;
use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Mojo::File qw /path tempfile/;
use Data::Dumper;
use Time::HiRes;
use autodie;
use Model::Tune;
use Model::Utils;
use Carp::Always;
use Mojo::JSON qw(encode_json);

my @alsaevents = ([
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    0,    0  ],{starttime=> 1.200, duration=>1.789}
],[
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    76,    0,    0  ],{starttime=>1.900, duration=>0.789}
]);
my $res = Model::Utils::alsaevent2scorenote(@{$alsaevents[0]});
#warn "0event: ".Dumper $alsaevents[0];
warn Dumper $res;
my @score=();
is(encode_json($res), '["note",115,171,0,72,71]');
push @score, $res;
push @score, Model::Utils::alsaevent2scorenote(@{$alsaevents[1]});
warn Dumper @score;
my $tune = Model::Tune->from_midi_score(\@score);
$tune->calc_shortest_note;
$tune->score2notes;
print $tune->to_string;

$tune->calc_shortest_note;
warn "finish calc_shortest_note";
$tune->score2notes;
is($tune->notes->[1]->to_string, "1;1;D6        # 0.1-1/8", 'Expected');
done_testing;
