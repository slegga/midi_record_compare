#!/usr/bin/env perl
use Mojo::Base -strict;
use Mojo::File;

=head1 NAME

 - cleanup a note csv file

=head DESCRIPTION

Ment to be used to convert samples to blueprints.
Remove comments and add new ones.

=cut

#
#			MAIN
#

my $filename = shift @ARGV;

# remove old comments

