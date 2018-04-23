use Test::More;
use FindBin;
use lib "lib";
use Clone 'clone';
use Model::Tune;
use Mojo::Base -strict;
use Mojo::File qw /path/;
use Data::Dumper;
use Carp::Always;
my $bluepr_file = path("$FindBin::Bin/../blueprints/polser_her.txt");
my $played_file = path("$FindBin::Bin/notes/polser-her-disorder.txt");
my $bluepr_tune = Model::Tune->from_note_file("$bluepr_file");
is(Model::Utils::Scale::guess_scale($bluepr_tune->notes),'c_dur','Guessed correct');
my $played_tune = Model::Tune->from_note_file("$played_file");

diag $played_tune->evaluate_with_blueprint($bluepr_tune);
ok(1,'dummy');
done_testing;
__END__
$tune->to_note_file($note_file);
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
is_deeply( extract_midi($midi_tune->notes), extract_midi($tune->notes) );

#
#	SUBS
#

sub extract_midi {
	my $notes = shift; #array_ref of notes
	my $return=[]; #arrays of hashes as midi note data
	for my $note (@$notes) {
		my $rr={};
		for my $key(qw/starttime duration note/) {
			$rr->{$key} = $note->$key;
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
