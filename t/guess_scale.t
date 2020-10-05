use Test::More;
use FindBin;
use lib "lib";
use Music::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path/;
use Carp::Always;
my $bluepr_file = path("t/blueprints/sonata-in-f.txt")->slurp;
my $bluepr_tune = Music::Tune->from_string("$bluepr_file");
is(Music::Utils::Scale::guess_scale_from_notes($bluepr_tune->notes),'eis_dur','Guessed correct');

done_testing;
__END__
