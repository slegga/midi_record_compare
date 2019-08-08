package Model::Blueprints;
use Mojo::Base -base;
use Mojo::File qw(tempfile path);
use File::Basename;
use MIDI;
use Encode 'decode';
use open ':encoding(UTF-8)';
use File::Basename 'basename';

# TODO fjern linjen under. Ingen printing fra denne modulen
use Term::ANSIColor;


use Model::Utils;
use Model::Tune;

=head1 NAME

Model::Blueprints - Takes order from UI

=head1 SYNOPSIS

use Model::Blueprints;
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

# has denominator =>8;
# has tune => sub {Model::Tune->new};
# has midi_events => sub {[]};
# has shortest_note_time => 9;
has blueprints_dir => sub {path("$FindBin::Bin/../blueprints")};
has blueprints => sub{[]}; # [ [65,66,...], Mojo::File ]
has 'last_comp';
=head1 METHODS

=head2 init

Initialize Blueprints object loads all the blueprints

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

=head2 do_comp

Do compare played tune with an blueprint.

=cut

sub do_comp {
    my ($self, $tune, $name) = @_;
    die "Missing self" if !$self;
    die "Missing (played) tune" if !$tune;
    return if ! $name;
    say "compare $name";
    my $filename = $name;
    if (! -e $filename) {
	    my $bluedir = $self->blueprints_dir->to_string;
        #say $bluedir;
        if ( -e $self->blueprints_dir->child($filename)) {
	        $filename = $self->blueprints_dir->child($filename);
        } else {
        	my $lbf = $self->local_dir($self->blueprints_dir);
        	if (-e $lbf) {
        		$filename = $lbf;
        	} else {
                my ($cand) = grep {$_=~ /$name/} map{$_->to_string} $self->blueprints_dir->list->each;
                if ($cand) {
                    $filename = $cand;
                    print $filename;

                } else {
                   warn "$filename or ".$self->blueprints_dir->child($filename).", $lbf or regex $name not found.";
                   return;
                }
    	    }
        }
	}

    #midi_event: ['note_on', dtime, channel, note, velocity]
    if  ( @{$tune->in_midi_events } < 8 ) {
        if (scalar @{$tune->notes} <8) {
            say "Notthing to work with. Less than 8 notes";
            return;
        }
    } else {
        my $score = MIDI::Score::events_r_to_score_r( $tune->in_midi_events );
    #    warn p($score);
        #score:  ['note', startitme, length, channel, note, velocity],
        $tune = (Model::Tune->from_midi_score($score));
    }
    if ($filename) {
        $self->last_comp($filename);
    }
    my $tune_blueprint= Model::Tune->from_note_file($filename);
    $tune->denominator($tune_blueprint->denominator);

    $tune->calc_shortest_note;
    $tune->score2notes;
    #say "Played notes after:  ".join(',',map {$self->pn($_->note)} @{$self->tune->notes});
    my $play_bs = $tune->get_beat_sum;
   	my $blueprint_bs = $tune_blueprint->get_beat_sum;
    printf "beatlengde før   fasit: %s, spilt: %s\n",$blueprint_bs,$play_bs;
   	if ($play_bs*1.5 <$blueprint_bs || $play_bs > 1.5*$blueprint_bs) {
        say "###### NÅ BLIR DET FEIL!!!!";
        $tune->beat_score($tune->beat_score/2) ;
        my $old_shortest_note_time = $tune->shortest_note_time;
	    say "SHORTEST NOTE TIME " .$tune->shortest_note_time . "$old_shortest_note_time * $play_bs / $blueprint_bs";
        $tune->shortest_note_time($old_shortest_note_time * $play_bs / $blueprint_bs);
        $tune->score2notes;
        $play_bs = $tune->get_beat_sum;
        printf "beatlengde etter fasit: %s, spilt: %s\n",$blueprint_bs,$play_bs;
    }

    #$self->denominator($self->tune->denominator);

    #$self->shortest_note_time($self->tune->shortest_note_time);
    $tune->evaluate_with_blueprint($tune_blueprint);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$tune->shortest_note_time,$tune->denominator;
    printf "Navn:          %s\n", color('blue') . basename($tune_blueprint->note_file) . color('reset');
    printf "Korteste note: %s\n", $tune->shortest_note_time;
    printf "Totaltid:      %5.2f\n", $tune->totaltime;
    return $self;
}

=head2 do_list

List files in the notes and blueprints directory

=cut

sub do_list {
    my ($self, $name) = @_;
    say '';
    say "notes/";
    my $notes_dir = path("$FindBin::Bin/../notes");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");

    say '';
    say "blueprints/";
    say decode('utf8',$self->blueprints_dir->list_tree->map(sub{basename($_)})->join("\n"));
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

=head2 do_play_blueprint

Play compared blueprint

=cut

sub do_play_blueprint {
    my ($self, $note_file) = @_;
    my $tmpfile = tempfile(DIR=>'/tmp');
    my $blueprint;
    my $bdf = $self->blueprints_dir->child($note_file)->to_string;
    if (defined $note_file) {
        if ( -f $note_file) {
            $blueprint = Model::Tune->from_note_file($note_file);
 		} elsif (-f $bdf) {
            $blueprint = Model::Tune->from_note_file($bdf);
  		} else {
  			for my $f(sort {length $a <=> $b} $self->blueprints_dir->list->each) {
  				if ("$f" =~ /$note_file/) {
  					$blueprint = Model::Tune->from_note_file("$f");
  					last;
  				}
  			}
  		}
  		if(! $blueprint) {
        	warn "note_file does not exists $note_file";
        	return;
        }
    } elsif ($self->tune->blueprint_file) {
        $blueprint = Model::Tune->from_note_file($self->tune->blueprint_file);
    }
    say path($blueprint->note_file)->basename;
    $blueprint->notes2score;
    $blueprint->to_midi_file("$tmpfile");
    print `timidity $tmpfile`;

}

=head2 do_save

Save played tune to disk in local/notes directory as notes (txt)

=cut

sub do_save {
    my ($self, $tune, $name) = @_;
    return if !$name;
    $name .= '.txt' if ($name !~/\.midi?$/);
    $tune->to_note_file($self->local_dir($self->blueprints_dir->child('notes'))->child($name));
}

=head2 do_save_midi

Save played tune as midi

=cut

sub do_save_midi {
    my ($self, $name) = @_;
    $name .= '.midi' if ($name !~/\.midi?$/);
    $self->tune->to_midi_file($self->local_dir($self->blueprints_dir->child('notes'))->child($name));
}

=head2 guess_blueprint

Return guessed blueprint based on played notes.

=cut

sub guess_blueprint {
    my $self = shift;
    my $tune = shift;
    if (@{$tune->notes} <10) {
        say "For kort låt for å sammenligne";
        return;
    }

    # Reduce number of candidates for each note played until one.
    my @candidates = @{$self->blueprints};
    my $i =0;
    my $bestname;
    for my $n( map {$_->note} @{$tune->notes}) {
    	next if ! defined $n;
        for my $j(reverse 0 .. $#candidates) {
        	next if ! defined $candidates[$j][0][$i];
            splice(@candidates,$j,1) if $n != $candidates[$j][0][$i];
        }
        if (@candidates == 1) {
            $bestname = $candidates[0][1];
            last;
        }
        if (@candidates == 0 ) {
        	last;
        }
        $i++;
        if ($i>10) {
            say "Flere kandidater etter 10 noter er spilt. Fjern en av fasitene";
            return;
        }
    }
    if (! defined $bestname) {
        printf "Ingen passende fasit er funnet etter %s noter", $i+1;
        return;
    }
    return $bestname;
}


=head2 local_dir

Find local dir. Where to save tunes.

=cut

sub local_dir {
	my ($self, $mojofiledir) =@_;

    my $mf = path("$mojofiledir");
	my @l = @$mf;
	my $remove=1;
	splice(@l,$#$mf-1, $remove, 'local');
	return path(@l);
}

=head2 pn

Return note for print

=cut

#sub pn {
#	my ($self, $note) = @_;
#	return if !defined $note;
#    return Model::Utils::Scale::value2notename($self->tune->scale,$note);
#}


1;