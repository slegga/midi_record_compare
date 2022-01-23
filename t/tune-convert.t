use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Music::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path tempfile/;
use Data::Dumper;
my $orginal_file_c = path("$FindBin::Bin/blueprints/lista_gikk_til_skolen_en_haand.txt")->slurp;
my $note_file = tempfile;
my $tune = Music::Tune->from_string($orginal_file_c);
$note_file->spurt($tune->to_string);
is( remove_comments($note_file->slurp), remove_comments($orginal_file_c),'Read write notefile');
my $new_tune = clone $tune;
is_deeply($tune,$new_tune,'Do clone work');
$tune->notes2score;
#warn Dumper $tune->notes;
$tune->score2notes;
#warn Dumper $tune->notes;
my $score2notes_file = tempfile;
$score2notes_file->spurt($tune->to_string);
is(remove_comments($score2notes_file->slurp),remove_comments($orginal_file_c),'test notes2score and back');

# Test write read midi file
my $midi_file = tempfile(SUFFIX =>'.mid');
$midi_file->spurt($tune->to_midi_file_content);
my $midi_tune = Music::Tune->from_midi_file($midi_file);
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

# DATA
my $old_data = $midi_tune->to_data;
my $new_midi_tune= Music::Tune->from_data($old_data);
my $new_data = $new_midi_tune->to_data;
is_deeply ($old_data,$new_data,'Datastructure is OK');

done_testing;
