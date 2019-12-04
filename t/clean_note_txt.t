use Mojo::Base -strict;
use Test::More;
# use Test::Warn;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/../../utilities-perl/lib";
use Model::Input::EventTest;
use Test::ScriptX;
$ENV{MOJO_MODE}='dry-run';
ok(1,'test');
...;# copy blueprint to_testarena/clean_note_txt_test.txt
my $t = Test::ScriptX->new('bin/clean_note_txt.pl',extra=>['t/testarena/clean_note_txt_test.txt']);
$t->run;
$t->stderr_ok->stdout_like(qr{note_on});
done_testing;
