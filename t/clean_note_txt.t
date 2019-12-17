use Mojo::Base -strict;
use Test::More;
# use Test::Warn;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/../../utilities-perl/lib";
use Model::Input::EventTest;
use Test::ScriptX;
use File::Copy 'copy';
$ENV{MOJO_MODE}='dry-run';
ok(1,'test');
unlink('t/testarena/*');
copy('t/startpos/clean_note_txt_test.txt','t/testarena/clean_note_txt_test.txt');
my $t = Test::ScriptX->new('bin/clean_note_txt.pl',extra_options=>['t/testarena/clean_note_txt_test.txt']);
$t->run('t/testarena/clean_note_txt_test.txt'=>1);
$t->stderr_ok->stdout_like(qr{note_on});
done_testing;
