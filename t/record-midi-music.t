use Mojo::Base -strict;
use Test::More;
use Mojo::File 'path';
use Test::FailWarnings;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/lib";

my $tmpdir = "$FindBin::Bin/../local";
mkdir($tmpdir )//die"cant make $tmpdir" if (! -d $tmpdir);
$tmpdir = "$FindBin::Bin/../local/notes";
mkdir($tmpdir )//die"cant make $tmpdir" if (! -d $tmpdir);


$ENV{MOJO_MODE}='dry-run';
require "$FindBin::Bin/../bin/record-midi-music.pl";
ok(1,'test');
my $t = __PACKAGE__->new;
$t->blueprints->blueprints_dir(path('t/blueprints'));
ok($t->blueprints->do_list,'OK');
ok($t->blueprints->do_save($t->tune,'test'),'OK');

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
my @midievents = map{Music::Utils::alsaevent2midievent(@$_)} grep {defined} @alsaevents;

$t->tune->in_midi_events(\@midievents);
my $fa = $t->blueprints->get_pathfile_by_name('lista_gikk_til_skolen_en_haand.txt');
my $fb = $t->blueprints->get_pathfile_by_name('lista');
#diag "$fa $fb";
like($fa,qr'/lista_gikk_til_skolen_en_haand.txt$','Both gets is correct');
like($fb,qr'/lista_gikk_til_skolen_en_haand.txt$','Both gets is correct');
ok($t->blueprints->do_comp($t->tune, $fa ),'OK');
done_testing;
