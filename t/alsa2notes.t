use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Model::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path tempfile/;
use Data::Dumper;
use Time::HiRes;
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
warn "0event: ".Dumper $alsaevents[0];
warn Dumper $res;
is($res->to_string, "0;0;C6        # 0.0-", 'Expected');
done_testing;
