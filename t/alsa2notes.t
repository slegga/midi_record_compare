use Mojo::Base -strict;
use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Mojo::File qw /path tempfile/;
use Data::Dumper;
use Time::HiRes;
use autodie;
use Music::Tune;
use Music::Utils;
#use Carp::Always;
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
my $res = Music::Utils::alsaevent2midievent(@{$alsaevents[0]});
#warn "0event: ".Dumper $alsaevents[0];
# warn Dumper $res;
my @events=();
is(encode_json($res), '["note_on",0,0,72,71]');
push @events, $res;
for  my $i (1 ..3 ){
    push @events, Music::Utils::alsaevent2midievent(@{$alsaevents[$i]});
}
# warn Dumper @score;
my $score = MIDI::Score::events_r_to_score_r( \@events );
my $tune = Music::Tune->from_midi_score($score);
$tune->calc_shortest_note;
$tune->score2notes;
print $tune->to_string;

$tune->calc_shortest_note;
say  "# finish calc_shortest_note";
$tune->score2notes;
is($tune->notes->[1]->to_string, "1;2;D5        # 1.1-1/2", 'Expected');
is(Music::Note->from_score($score->[1],{tune_starttime=>0
,shortest_note_time=>$tune->shortest_note_time, denominator=>4, prev_starttime=>$score->[0]->[1]}
    )->to_string, '1;2;D5        # 1.1-1/2','Not working yet');

# test Olavs piano
@alsaevents = ([
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
  [    0,    72,    0,    50  ],{dtime_sec=>1.5}
],[
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    0,   100  ],{dtime_sec=>0}
]);
$res = Music::Utils::alsaevent2midievent(@{$alsaevents[2]});
#warn "0event: ".Dumper $alsaevents[0];
# warn Dumper $res;
is(encode_json($res), '["note_off",144.0,0,72,0]');

done_testing;
