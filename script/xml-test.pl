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

use FindBin;
use lib "$FindBin::Bin/../../utilities-perl/lib";
use SH::UseLib;
use Music::Utils::Scale;
my $handsplit_y=-80;
# Convertion from a XML String to a Hash
if(1) {
	my $xml_converter = XML::Hash->new();
	my $xml =  $xml_converter->fromXMLStringtoHash('helloworld.musicxml');
	#	$p->validation(1);
#	my $xml_hash = $p->load_xml(location => 'lg-69390178.xml');#'notes/Alan_Walker_-_All_Falls_Down.mxl');
	print Dumper $xml;
} else {
	my $xml_converter = XML::Hash->new();
	my $xml =  $xml_converter->fromXMLStringtoHash('lg-69390178.xml');

	#	say join("\n",keys %{$xml->{'score-partwise'}});
	#p $xml->{'score-partwise'}->{part}->{measure};

	# Loop thorugh hash, create array og hashes of notes
	my $prev = {left=>{ x => 0, d => 10000, measure => 0},right=>{x => 0, d => 10000, measure => 0}};
	my @notes;
	my $point_in_time=0;
    my $measure = 0;
	for my $n(@{ $xml->{'score-partwise'}->{part}->{measure} }) {
		$measure = $n->{number};
		for my $m(sort {int($a->{'default-x'}/12) <=> int($b->{'default-x'}/12)} grep {exists $_->{'default-x'}} @{$n->{note}}) {
	#		p $m;
			my $x = int($m->{'default-x'}/12);
			my $d = $m->{duration}->{text};
			my $hand = $m->{'default-y'} >$handsplit_y ? 'right' :'left';
			my $other_hand = ($hand eq 'right'?'left':'right' );
			#say join(' ',$x, $m->{'default-y'}, $m->{duration}->{text},j($m->{pitch}));
			# 0;1;G4        # 0.0-1/2
			my $pause=0;
			if ($prev->{$hand}->{d} == 10000) {
				$prev->{$hand}->{d} = $prev->{$other_hand}->{d};
			}
			if (!$prev->{$hand}->{x}) {
				$prev->{$hand}->{x} = $x;
			}
#			warn "$prev->{$hand}->{x} == $x && $prev->{$hand}->{measure} == $measure";
			if ( $prev->{$hand}->{x} == $x && $prev->{$hand}->{measure} == $measure) {
				if ($prev->{$hand}->{d} > $d) {
					$prev->{$hand}->{d} = $d;
				}
				$pause = 0;
			} else {
				$pause = $prev->{$hand}->{d};
				$prev->{$hand}->{d} -=$prev->{$other_hand}->{d};
			}

			$point_in_time += $pause;

			my $note = { pause=> $pause, duration=> $m->{duration}->{text}, pitch => { step => $m->{pitch}->{step}->{text}, octave => $m->{pitch}->{octave}->{text}, alter => $m->{pitch}->{alter}->{text}}
				, x => $m->{'default-x'}, y => $m->{'default-y'} };
			$note->{tie} = $m->{tie}->{type} if exists $m->{tie};
			$note->{start} = $point_in_time;
			$note->{end} = $note->{start} + $note->{duration};
			$note->{measure} = $measure;
			$note->{hand} = $hand;
			push @notes, $note;
			$prev->{$hand}->{d} = $m->{duration}->{text};
			$prev->{$hand}->{x} = $x;
			$prev->{$hand}->{measure} = $measure;
		}
	}

	# loop to concat tied notes

	STOP: for my $i(reverse 0 .. $#notes) {
		if (exists $notes[$i]{tie} && $notes[$i]{tie} eq 'stop') {
			for my $j(reverse 0 .. ($i-1)) {
				if (exists $notes[$j]{tie} && $notes[$j]{tie} eq 'start') {
					if ($notes[$i]{start} == $notes[$j]{end} && $notes[$i]{pitch}{step} eq $notes[$i]{pitch}{step} && $notes[$i]{pitch}{octave} eq $notes[$i]{pitch}{octave}
					&& $notes[$i]{pitch}{alter} eq $notes[$i]{pitch}{alter}) {
						$notes[$j]{duration} += $notes[$i]{duration};
						delete $notes[$j]{tie};
						splice @notes,$i,1; # delete last tied note
						last;
					}
					elsif ($notes[$i]{start} < $notes[$j]{end}) {
						p $notes[$j];
						p $notes[$i];
						warn "$j $i";
					}
				}
				next if $j>$i;
			}
		}
	}
	# print output based on array of hashes

	my $denominator = 8;
	my $scale = 'cis_dur';
	printf "denominator=%d\n",$denominator;
	printf "shortest_note_time=%d\n", 200/$denominator;
	print  "beat_score=100\n";
	printf "scale=$scale\n";

	for my $note(@notes) {
		my $nname = sprintf('%s%d',$note->{pitch}->{step}, $note->{pitch}->{octave});
		$nname = Music::Utils::Scale::alter_notename($scale, $nname, $note->{pitch}->{alter});
		printf "%s;%s;%s #%s %s %s %s %s\n", $note->{pause}, $note->{duration}, $nname, $note->{x}, $note->{y}
		. (exists $note->{tie} ? $note->{tie} : ''), $note->{start}, $note->{end},$note->{hand};
	}
}
