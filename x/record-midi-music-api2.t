use Mojo::Base -strict;
use Test::More;
# use Test::Warn;
use Test::FailWarnings;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib 't';
use Music::Input::EventTest;
use Test::ScriptX;
$ENV{MOJO_MODE}='dry-run';
ok(1,'test');
my $t = Test::ScriptX->new('bin/record-midi-music.pl',input_object => Music::Input::EventTest->new, debug=>1);

$t->run(api=>1);
$t->stderr_ok->stdout_like(qr{note_on});
done_testing;
