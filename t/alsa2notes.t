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
  6,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    0  ],{dtime_sec=>0}
],[
  6,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    76,    0  ],{dtime_sec=>1}
],
[
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    50  ],{dtime_sec=>1.5}
],[
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    76,   100  ],{dtime_sec=>0}
]);
my $res = Model::Utils::alsaevent2midievent(@{$alsaevents[0]});
#warn "0event: ".Dumper $alsaevents[0];
# warn Dumper $res;
my @events=();
is(encode_json($res), '["note_on",0,0,72,71]');
push @events, $res;
for  my $i (1 ..3 ){
    push @events, Model::Utils::alsaevent2midievent(@{$alsaevents[$i]});
}
# warn Dumper @score;
my $score = MIDI::Score::events_r_to_score_r( \@events );
my $tune = Model::Tune->from_midi_score($score);
$tune->calc_shortest_note;
$tune->score2notes;
print $tune->to_string;

$tune->calc_shortest_note;
say  "# finish calc_shortest_note";
$tune->score2notes;
is($tune->notes->[1]->to_string, "1;2;D6        # 0.1-1/2-96.00", 'Expected');
is(Model::Note->from_score($score->[1],{tune_starttime=>0
,shortest_note_time=>$tune->shortest_note_time, denominator=>4}
    )->to_string, '0;2;D6        # 0.0-1/2','Not working yet');
done_testing;
