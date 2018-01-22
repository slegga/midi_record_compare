use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Model::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path tempfile/;
use Data::Dumper;
use Time::HiRes;
my $note = Model::Note->new();
my @alsaevents = ((
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    0,    0  ],{starttime=> 12.200, duration=>124.789}
),(
  7,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    74,    76,    0,    0  ],{starttime=>133.200, duration=>134.789}
));
my $res = $note->from_alsaevent($alsaevents[0])->to_string;
warn $res;
is_deeply($res, "123 333 4", 'Expected');
done_testing;
