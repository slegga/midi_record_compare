#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Mojo::File 'path';
use Term::ANSIColor;
use Model::Tune;

=head1 NAME

colornotes.pl - Print notes with error coloring

=head1 DESCRIPTION

Read lines and print with diffrent colors based on if it looks right or not.

=over

=item green - Looks ok

=item red - Miss first beat into tempo

=item yellow - stacato



=back

=head2 DESIGN

Leser inn tune. Rekalkulerer.
Markerer left/right per note.


=cut

#,{return_uncatched_arguments => 2});
option 'extend=s', 'Extend these periods to next valid length. Takes , separated list';
option 'scale=s', 'Set scale. Convert from old to given scale. Example c_dur';
option 'ticsprbeat=i', 'Number of tics. Examle 6.';


sub main {
    my $self = shift;
    my ($tunefile) = ($self->extra_options)[0];
    my $tune = Model::Tune->from_note_file($tunefile);
    my $new_scale;
    if ($self->scale) {
        $new_scale = $self->scale;
    } else {
        $new_scale = Model::Utils::Scale::guess_scale_from_notes($tune->notes);
    }
    if ($new_scale ne $tune->scale) {
        $tune->scale($new_scale);
    }

    if ($self->ticsprbeat) {
        $tune->denominator($self->ticprbeat);
    }

    for my $line(@{ $tune->notes }) {
    	# code for split left and right
    	# split
    	# look back to se if ok
    	if ($line eq '') {
    		...;
    	} else {
    		print color('green');
    	}
    	print $line;
    }
    print color('reset');
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();

__END__
#!/usr/bin/env perl

use MIDI; # uses MIDI::Opus et al
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
#use Carp::Always;
use Model::Tune;


 - cleanup a note txt file


Ment to be used to convert samples to blueprints.
Remove comments and add new ones.
Can change scale.


option 'extend=s', 'Extend these periods to next valid length. Takes , separated list';
option 'scale=s', 'Set scale. Convert from old to given scale. Example c_dur';
option 'ticsprbeat=i', 'Number of tics. Examle 6.';
#,{return_uncatched_arguments => 1});
 sub main {
    my $self = shift;
    my @e = $self->extra_options;
    say Dumper \@e;
    my $filename = ($self->extra_options)[0];
    die "No file given" if ! $filename;
    my $tune = Model::Tune->from_note_file($filename);
    my $new_scale;
    if ($self->scale) {
        $new_scale = $self->scale;
    } else {
        $new_scale = Model::Utils::Scale::guess_scale_from_notes($tune->notes);
    }
    if ($new_scale ne $tune->scale) {
        $tune->scale($new_scale);
    }

    if ($self->ticsprbeat) {
        $tune->denominator($self->ticprbeat);
    }

    say "$tune";
    $tune->to_note_file; # will write notes based on $tune->scale
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();

