#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utillities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::Script qw/options_and_usage/;

use Mojo::Base -strict;
use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
#use Carp::Always;
use Model::Tune;

=head1 NAME

 - cleanup a note csv file

=head1 DESCRIPTION

Ment to be used to convert samples to blueprints.
Remove comments and add new ones.

=cut

my ( $opts, $usage, $argv ) =
    options_and_usage( $0, \@ARGV, "%c %o",
    [ 'extend|e=s', 'Extend these periods to next valid length. Takes , separated list' ],
,{return_uncatched_arguments => 1});



my $tune = Model::Tune->new(file=>$ARGV[0]);
$tune->notes_from_file;
#$tune->spurt;
say "$tune";

__END__
#!/usr/bin/env perl
use Mojo::Base -strict;
use Mojo::File 'path';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Model::Tune;
use Model::Note;


#
#			MAIN
#
