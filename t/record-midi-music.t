use Mojo::Base -strict;
use Test::More;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/lib";

$ENV{MOJO_MODE}='dry-run';
require "$FindBin::Bin/../bin/record-midi-music.pl";
ok(1,'test');
my $t = __PACKAGE__->new;
ok($t->action->do_list,'OK');
ok($t->action->do_save('test'),'OK');

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
],
[
  6,  0,  0,  253,  0,  [    20,    0  ],
  [    128,    0  ],
  [    0,    72,    71,    0  ],{dtime_sec=>1}
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
my @midievents = map{Model::Utils::alsaevent2midievent(@$_)} grep {defined} @alsaevents;

$t->action->midi_events(\@midievents);
ok($t->action->do_comp('lista_gikk_til_skolen_en_haand.txt'),'OK');
done_testing;
