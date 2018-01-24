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
use Carp::Always;

my $tune = Model::Tune->new();

my @alsaevents = ([
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    0,    0  ],{starttime=> 12.200, duration=>124.789}
],[
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    76,    0,    0  ],{starttime=>133.200, duration=>134.789}
]);
my $res = Model::Note->from_alsaevent(@{$alsaevents[0]});
#warn "0event: ".Dumper $alsaevents[0];
warn Dumper $res;
is($res->to_string, "0;0;C6        # 0.0-", 'Expected');
push @{$tune->notes}, $res;
push @{$tune->notes}, Model::Note->from_alsaevent(@{$alsaevents[0]});
$tune->calc_shortest_note;
warn "finish calc_shortest_note";
$tune->score2notes;
warn Dumper $tune->notes;
is($res->to_string, "0;12;C6       # 0.0-3/1", 'Expected');
ok(1,'End');
done_testing;
