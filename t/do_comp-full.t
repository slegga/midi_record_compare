use Mojo::Base -strict;
use Test::More;
use Carp::Always;
use FindBin;
use Data::Printer;
use lib "../lib";
use lib "$FindBin::Bin/lib";
require "$FindBin::Bin/../bin/record-midi-music.pl";
ok(1,'test');
my $t = __PACKAGE__->new;

my @alsaevents = (
  [6,0,0,253,0,[20,0],[129,0],[0,55,90,0,0],{"dtime_sec"=>5.62953519821167}]
, [6,0,0,253,0,[20,0],[129,0],[0,48,95,0,0],{"dtime_sec"=>0.00504183769226074}]
, [6,0,0,253,0,[20,0],[129,0],[0,64,92,0,0],{"dtime_sec"=>0.017333984375}]     # 0 lenger lengde
, [6,0,0,253,0,[20,0],[129,0],[0,62,96,0,0],{"dtime_sec"=>0.733664989471436}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,100,0,0],{"dtime_sec"=>0.631814956665039}]
, [6,0,0,253,0,[20,0],[129,0],[0,55,91,0,0],{"dtime_sec"=>0.199860811233521}]
, [6,0,0,253,0,[20,0],[129,0],[0,48,79,0,0],{"dtime_sec"=>0.0206301212310791}]
, [6,0,0,253,0,[20,0],[129,0],[0,64,90,0,0],{"dtime_sec"=>0.0113799571990967}] # 0 nesten samme lengde
, [6,0,0,253,0,[20,0],[129,0],[0,62,95,0,0],{"dtime_sec"=>0.620151042938232}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,81,0,0],{"dtime_sec"=>0.676090002059937}]
, [6,0,0,253,0,[20,0],[129,0],[0,48,98,0,0],{"dtime_sec"=>0.193305969238281}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,81,0,0],{"dtime_sec"=>0.0298750400543213}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,83,0,0],{"dtime_sec"=>0.164952993392944}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,77,0,0],{"dtime_sec"=>0.15558910369873}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,85,0,0],{"dtime_sec"=>0.171225786209106}] # bytte
, [6,0,0,253,0,[20,0],[129,0],[0,55,98,0,0],{"dtime_sec"=>0.0741190910339355}]
, [6,0,0,253,0,[20,0],[129,0],[0,62,88,0,0],{"dtime_sec"=>0.0135281085968018}] # 0 problemet skulle vært 1
, [6,0,0,253,0,[20,0],[129,0],[0,62,96,0,0],{"dtime_sec"=>0.162255048751831}]
, [6,0,0,253,0,[20,0],[129,0],[0,62,94,0,0],{"dtime_sec"=>0.163842916488647}]
, [6,0,0,253,0,[20,0],[129,0],[0,62,92,0,0],{"dtime_sec"=>0.191756010055542}]
, [6,0,0,253,0,[20,0],[129,0],[0,55,83,0,0],{"dtime_sec"=>0.113744020462036}]
, [6,0,0,253,0,[20,0],[129,0],[0,48,93,0,0],{"dtime_sec"=>0.00798892974853516}]
, [6,0,0,253,0,[20,0],[129,0],[0,64,94,0,0],{"dtime_sec"=>0.0134520530700684}] #0 nesten samme lengde
, [6,0,0,253,0,[20,0],[129,0],[0,62,94,0,0],{"dtime_sec"=>0.781949043273926}]
, [6,0,0,253,0,[20,0],[129,0],[0,60,82,0,0],{"dtime_sec"=>0.633203029632568}]
);
my @midievents = map{Model::Utils::alsaevent2midievent(@$_)} grep {defined} @alsaevents;
$t->action->midi_events(\@midievents);
ok($t->action->do_comp('polser_her.txt'),'OK');
diag $t->action->do_comp('polser_her.txt');
$t->action->init;
diag p($t->action->blueprints);
like($t->action->guessed_blueprint,qr'polser_her.txt$','Tipper riktig sang');
done_testing;
