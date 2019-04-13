#!/usr/bin/env perl

=head1 NAME

xml-test.pl

=head1 DESCRIPTION

Manual Test on do xml to hash

=cut

use Mojo::Base -strict;
use Data::Printer {max_depth=>10};
use XML::LibXML;
use Mojo::File 'path';
use Data::Dumper;
use XML::Hash;
use Mojo::JSON 'j';
# Convertion from a XML String to a Hash
if(0) {
	my $p = XML::LibXML->new();
	$p->validation(1);
	my $xml_hash = $p->load_xml(location => 'lg-69390178.xml');#'notes/Alan_Walker_-_All_Falls_Down.mxl');
	print Dumper $xml_hash;
} else {
	my $xml_converter = XML::Hash->new();
	my $xml =  $xml_converter->fromXMLStringtoHash('lg-69390178.xml');

#	say join("\n",keys %{$xml->{'score-partwise'}});
#p $xml->{'score-partwise'}->{part}->{measure};
for my $n(@{ $xml->{'score-partwise'}->{part}->{measure} }) {
#	p $n;
#	next;
	for my $m(sort {$a->{'default-x'} <=> $b->{'default-x'}}@{$n->{note}}) {
#		p $m;
		say join(' ',$m->{'default-x'}, $m->{'default-y'}, $m->{duration}->{text},j($m->{pitch}));
	}
}
#	$xml_converter->fromXMLStringtoHash($xml);
}