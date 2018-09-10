use Mojo::Base -strict;
use Test::More;
# use Test::Warn;
use Test::FailWarnings;
use Carp::Always;
use FindBin;
use lib "../lib";
use lib "$FindBin::Bin/lib";
use Model::Input::EventTest;

$ENV{MOJO_MODE}='dry-run';
require "$FindBin::Bin/../bin/record-midi-music.pl";
ok(1,'test');
my $t = __PACKAGE__->new(input_object => Model::Input::EventTest->new)->with_options;
$t->main();
done_testing;
