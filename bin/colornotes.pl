#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use lib "$FindBin::Bin/../lib";
use SH::ScriptX;
use Mojo::Base 'SH::ScriptX';
use Mojo::File 'path';
use Term::ANSIColor;

=head1 NAME

colornotes.pl - Print notes with error coloring

=head1 DESCRIPTION

Read lines and print with diffrent colors based on if it looks right or not.

=over

=item green - Looks ok

=item red - Miss first beat into tempo

=item yellow - stacato


=back

=cut

#,{return_uncatched_arguments => 2});

sub main {
    my $self = shift;
    my ($tunefile) = ($self->extra_options)[0];
    my $notes_cont = path($tunefile)->slurp;
    for my $line(split (/\n/, $notes_cont)) {
    	# code for split left and right
    	# split
    	# look back to se if ok
    	if ($line eq '') {
    		...;
    	} else {
    		print color('green');
    	}
    	say $line;
    }
    print color('reset');
}

__PACKAGE__->new(options_cfg=>{extra=>1})->main();
