use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Model::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path tempfile/;
use Data::Dumper;
my $orginal_file = path("$FindBin::Bin/blueprints/lista_gikk_til_skolen_en_haand.txt");
my $note_file = tempfile;
my $tune = Model::Tune->from_note_file("$orginal_file");
$tune->to_note_file($note_file);
is( remove_comments($note_file->slurp), remove_comments($orginal_file->slurp),'Read write notefile');
my $new_tune = clone $tune;
is_deeply($tune,$new_tune,'Do clone work');
$tune->notes2score;
#warn Dumper $tune->notes;
$tune->score2notes;
#warn Dumper $tune->notes;
my $score2notes_file = tempfile;
$tune->to_note_file($score2notes_file);
is(remove_comments($score2notes_file->slurp),remove_comments($orginal_file->slurp),'test notes2score and back');

# Test write read midi file
my $midi_file = tempfile(SUFFIX =>'.mid');
$tune->to_midi_file($midi_file);
my $midi_tune = Model::Tune->from_midi_file($midi_file);
is_deeply( extract_midi($midi_tune->scores), extract_midi($tune->scores) );

#
#	SUBS
#

sub extract_midi {
	my $scores = shift; #array_ref of notes
	my $return=[]; #arrays of hashes as midi note data
	for my $score (@$scores) {
		my $rr={};
		for my $key(qw/starttime duration note/) {
			$rr->{$key} = $score->{$key};
		}
		push @$return, $rr;
	}
	return $return;
}

sub remove_comments {
	my $cont = shift;
	my $return='';
	for my $l(split /\n/, $cont) {
		$l =~ s/\s*\#.*//;
		next if ! $l;
		$return .= $l."\n";
	}
	return $return;
}


done_testing;
