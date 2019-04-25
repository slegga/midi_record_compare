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

	# Loop thorugh hash, create array og hashes of notes
	my $prev = {x=>0,d=>10000};
	my @notes;
	for my $n(@{ $xml->{'score-partwise'}->{part}->{measure} }) {
	#	p $n;
	#	next;
		if (0) {
			for my $x (@{$n->{note}}) {
				if (! exists $x->{'default-x'}) {
					warn "unhandeled";
					p $x;
				}
			}
		}
		for my $m(sort {int($a->{'default-x'}/12) <=> int($b->{'default-x'}/12)} grep {exists $_->{'default-x'}} @{$n->{note}}) {
	#		p $m;
			my $x = int($m->{'default-x'}/12);
			my $d = $m->{duration}->{text};
			#say join(' ',$x, $m->{'default-y'}, $m->{duration}->{text},j($m->{pitch}));
			# 0;1;G4        # 0.0-1/2
			my $pause=0;
			if (!$prev->{x}) {
				$prev->{x} = $x;
			}
			if ( $prev->{x} == $x ) {
				if ($prev->{d} > $d) {
					$prev->{d} = $d;
				}
				$pause = 0;
			} else {
				$pause = $prev->{d};
			}

			printf "%s;%s;%s%s #%s %s\n", $pause, $m->{duration}->{text}, $m->{pitch}->{step}->{text}, $m->{pitch}->{octave}->{text}, $m->{'default-x'}, $m->{'default-y'};
			$prev->{d} = $m->{duration}->{text};
			$prev->{x} = $x;
		}
	}

	# print output based on array of hashes
	# for my $note(@notes) {
	# }
}
