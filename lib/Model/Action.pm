package Model::Action;
use Mojo::Base -base;
use Mojo::File qw(tempfile path);
use File::Basename;
use MIDI;

# TODO fjern linjen under. Ingen printing fra denne modulen
use Term::ANSIColor;


use Model::Utils;
use Model::Tune;

=head1 NAME

Model::Action - Takes order from UI

=head1 SYNOPSIS

use Model::Action;
...;

=head1 DESCRIPTION

Handles request from UI either from cli or web.
Talk with Model modules like Model::Tune

=head1 ATTRIBUTES

=over

=item denominator: Part of beat which is the shortest note.

=item tune:        Tune object

=item midi_events: Temporary played notes.

=item shortest_note_time: How long the shortest note is in length.

=item blueprints_dir:     Where the blueprints are. Default to ./blueprints

=item blueprints:         Loaded on startup. Container for all blueprints as Tune objects.

=back

=cut

has denominator =>8;
has tune => sub {Model::Tune->new};
has midi_events => sub {[]};
has shortest_note_time => 9;
has blueprints_dir => sub {path("$FindBin::Bin/../blueprints")};
has blueprints => sub{[]}; # [ [65,66,...], Mojo::File ]

=head1 METHODS

=head2 init

Initialize Action object loads all the blueprints

=cut


sub init {
    # load blueprints
    my $self = shift;
    for my $b ($self->blueprints_dir->list->each) {
        my $tmp = Model::Tune->from_note_file("$b");
        my $num = scalar @{$tmp->notes};
        my $firstnotes;
        push @$firstnotes, $tmp->notes->[$_]->note for (0 .. 9);
        push @{$self->blueprints},[$firstnotes , "$b"];
    }

}

sub do_comp {
    my ($self, $name) = @_;
    die "Missing self" if !$self;

    return if ! $name;
    say "compare $name";
    my $filename = $name;
    if (! -e $filename) {
	    my $bluedir = $self->blueprints_dir->to_string;
        say $bluedir;
        if ( -e $self->blueprints_dir->child($filename)) {
	        $filename = $self->blueprints_dir->child($filename);
        } else {
        	my $lbf = $self->local_dir($self->blueprints_dir);
        	if (-e $lbf) {
        		$filename = $lbf;
        	} else {
	            warn "$filename or ".$self->blueprints_dir->child($filename)." or $lbf not found";
    	        return;
    	    }
        }
	}

    #midi_event: ['note_on', dtime, channel, note, velocity]
    if  ( @{$self->midi_events } < 8 ) {
        if (scalar @{$self->notes} <8) {
            say "Notthing to work with. Less than 8 notes";
            return;
        }
    } else {
        my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
    #    warn p($score);
        #score:  ['note', startitme, length, channel, note, velocity],
        $self->tune(Model::Tune->from_midi_score($score));
    }

    #say "Played notes:       ".join(',',map {$self->pn($_->note)} @{$self->tune->notes});

    my $tune_blueprint= Model::Tune->from_note_file($filename);
    $self->tune->denominator($tune_blueprint->denominator);

    $self->tune->calc_shortest_note;
    $self->tune->score2notes;
    #say "Played notes after:  ".join(',',map {$self->pn($_->note)} @{$self->tune->notes});
    my $play_bs = $self->tune->get_beat_sum;
   	my $blueprint_bs = $tune_blueprint->get_beat_sum;
    printf "beatlengde før   fasit: %s, spilt: %s\n",$blueprint_bs,$play_bs;
   	if ($play_bs*1.5 <$blueprint_bs || $play_bs > 1.5*$blueprint_bs) {
        say "######";
        $self->tune->beat_score($self->tune->beat_score/2) ;
        my $old_shortest_note_time = $self->tune->shortest_note_time;
        #my @new_score = map{$_->to_score({factor=>$blueprint_bs/$play_bs})} @{$self->tune->notes};
#	    $self->tune(Model::Tune->from_midi_score(\@new_score));
	    say "SHORTEST NOTE TIME $self->tune->shortest_note_time $old_shortest_note_time * $play_bs / $blueprint_bs";
        $self->tune->shortest_note_time($old_shortest_note_time * $play_bs / $blueprint_bs);
#        $self->tune->calc_shortest_note;
        $self->tune->score2notes;

    }
    $play_bs = $self->tune->get_beat_sum;
    printf "beatlengde etter fasit: %s, spilt: %s\n",$blueprint_bs,$play_bs;

    $self->denominator($self->tune->denominator);

    $self->shortest_note_time($self->tune->shortest_note_time);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;
    #say "Played notes after2:".join(',',map {$self->pn($_->note)} @{$self->tune->notes});

    $self->tune->evaluate_with_blueprint($tune_blueprint);
    return $self;
}

sub do_list {
    my ($self, $name) = @_;
    say '';
    say "notes/";
    my $notes_dir = path("$FindBin::Bin/../notes");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");

    say '';
    say "blueprints/";
    say $self->blueprints_dir->list_tree->map(sub{basename($_)})->join("\n");
}

sub do_endtune {
    my ($self) = @_;
    return $self if (@{$self->midi_events} <= 10);
    my $score = MIDI::Score::events_r_to_score_r( $self->midi_events );
    $self->tune(Model::Tune->from_midi_score($score));

    $self->tune->calc_shortest_note;
    $self->tune->score2notes;

    print $self->tune->to_string;
    $self->shortest_note_time($self->tune->shortest_note_time);
    $self->denominator($self->tune->denominator);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$self->shortest_note_time,$self->denominator;

    my $guess = $self->guessed_blueprint();
    return $self if ! $guess;
    print color('green');
    say "Tippet låt: ". ($guess);
    print color('reset');
    $self->do_comp($guess);
    return $self;
}

=head2 do_play

Takes self, filepathname
Plays self->tune or given filepathname

=cut

sub do_play {
    my ($self, $name) = @_;
    my $tmpfile = tempfile(DIR=>'/tmp');
    my $tune;
    if (defined $name) {
        if (-e $name) {
            if ($name =~ /midi?$/)  {
                print `timidity $name`;
                return;
            } else {
                $tune = Model::Tune->from_note_file($name);
                $tune->notes2score;
            }
        } else {
        	my $tmp = $self->blueprints_dir->child($name);
        	if( -e $tmp) {
	            $tune = Model::Tune->from_note_file($tmp);
	            $tune->notes2score;
	        } else {
	 			$tmp = $self->blueprints_dir->sibling('local','notes')->child($name);
	 			if (-e $tmp) {
		            $tune = Model::Tune->from_note_file($tmp);
		 	        $tune->notes2score;
		 	    } else {
	 				$tmp = $self->blueprints_dir->sibling('local','blueprints')->child($name);
    	 			if (-e $tmp) {
    		            $tune = Model::Tune->from_note_file($tmp);
    		 	        $tune->notes2score;
    		 	    } else {
    		 	    	warn "Did not find $name. Play stored tune instead.";
			            $tune = $self->tune;
    		 	    }
				}
			}
        }
    } else {
        $tune = $self->tune;
    }
    $tune->to_midi_file("$tmpfile");
    print `timidity $tmpfile`;
}



sub do_save {
    my ($self, $name) = @_;
    $name .= '.txt' if ($name !~/\.midi?$/);
    $self->tune->to_note_file($self->local_dir($self->blueprints_dir->child('notes'))->child($name));
}

sub do_save_midi {
    my ($self, $name) = @_;
    $name .= '.midi' if ($name !~/\.midi?$/);
    $self->tune->to_midi_file($self->local_dir($self->blueprints_dir->child('notes'))->child($name));
}


sub guessed_blueprint {
    my $self = shift;
    if (@{$self->tune->notes} <10) {
        say "For kort låt for å sammenligne";
        return;
    }

    # Reduce number of candidates for each note played until one.
    my @candidates = @{$self->blueprints};
    my $i =0;
    my $bestname;
    for my $n( map {$_->note} @{$self->tune->notes}) {
        for my $j(reverse 0 .. $#candidates) {
            splice(@candidates,$j,1) if $n != $candidates[$j][0][$i];
        }
        if (@candidates == 1) {
            $bestname = $candidates[0][1];
            last;
        }
        $i++;
        if ($i>10) {
            say "Flere kandidater etter 10 noter er spilt. Fjern en av fasitene";
            return;
        }
    }
    if (! defined $bestname) {
        say "Ingen passende fasit er funnet. Notenr-1: $i";
        return;
    }
    return $bestname;
}

sub local_dir {
	my ($self, $mojofiledir) =@_;

    my $mf = path("$mojofiledir");
	my @l = @$mf;
	my $remove=1;
	splice(@l,$#$mf-1, $remove, 'local');
	return path(@l);
}


sub pn {
	my ($self, $note) = @_;
	return if !defined $note;
    return Model::Utils::Scale::value2notename($self->tune->scale,$note);
}


1;
