use Test::More;
use FindBin;
use lib "lib";
use Model::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path/;
use Carp::Always;
my $bluepr_file = path("$FindBin::Bin/../blueprints/sonata-in-f.txt");
my $bluepr_tune = Model::Tune->from_note_file("$bluepr_file");
is(Model::Utils::Scale::guess_scale_from_notes($bluepr_tune->notes),'eis_dur','Guessed correct');
done_testing;
__END__
