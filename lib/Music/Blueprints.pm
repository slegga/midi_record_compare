package Music::Blueprints;
use Mojo::Base -base;
use Mojo::File qw(tempfile path curfile);
#use File::Basename;
use MIDI;
use Encode 'decode';
use open ':encoding(UTF-8)';
use File::Basename 'basename';

# TODO fjern linjen under. Ingen printing fra denne modulen
use Term::ANSIColor;


use Music::Utils;
use Music::Tune;

=head1 NAME

Music::Blueprints - Takes order from UI

=head1 SYNOPSIS

use Music::Blueprints;
...;

=head1 DESCRIPTION

Handles request from UI either from cli or web.
Talk with Model modules like Music::Tune

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
# has tune => sub {Music::Tune->new};
# has midi_events => sub {[]};
# has shortest_note_time => 9;
has blueprints_dir => sub {curfile->dirname->dirname->dirname->sibling('midi-blueprints')};
has blueprints => sub{[]}; # [ [65,66,...], Mojo::File ]

=head1 METHODS

=head2 init

Initialize Blueprints object loads all the blueprints

=cut


sub init {
    # load blueprints
    my $self = shift;
    for my $b ($self->blueprints_dir->list->each) {
        next if $b->basename !~/\.txt$/ ;
        my $tmp = Music::Tune->from_string($b->slurp);
        my $num = scalar @{$tmp->notes};
        my $firstnotes;
        push @$firstnotes, $tmp->notes->[$_]->note for (0 .. 9);
        push @{$self->blueprints},[$firstnotes , "$b"];
    }

}

=head2 do_comp

Do compare played tune with an blueprint with relative path.
Return $self if success and undef if failed.

Takes tune object and filename

=cut

sub do_comp {
    my ($self, $tune, $filename,$hand) = @_;
    die "Missing self" if !$self;
    die "Missing (played) tune" if !$tune;
    return if ! $filename;
    if (! -f $filename) {
        print STDERR "ERROR: File not found $filename";
        return
    }
    say "compare $filename";
	my $file = path($filename);
    #midi_event: ['note_on', dtime, channel, note, velocity]
    my $score = $tune->to_midi_score;
    if  ( @{$tune->in_midi_events } < 8 ) {
        if (scalar @{$tune->notes} <8) {
            if ("$file") {
                say "Notthing to work with. Less than 8 notes";
                return;
            } else {
                die "should never get here";
            }
        }
    } else {
    #score:  ['note', startitme, length, channel, note, velocity],
        $tune = Music::Tune->from_midi_score($score);
    }
    my $tune_blueprint= Music::Tune->from_string($file->slurp);
    $tune_blueprint->hand($hand) if (grep {$hand eq $_} (qw/left right/));
    $tune->denominator($tune_blueprint->denominator);
    my $new_shortest_note = $tune_blueprint->get_best_shortest_note($score);
    if ($new_shortest_note) {
        $tune->shortest_note_time($new_shortest_note);
    } else {
        $tune->calc_shortest_note_time; # calculate implesit
    }

    $tune->score2notes;
    #say "Played notes after:  ".join(',',map {$self->pn($_->note)} @{$self->tune->notes});
    my $play_bs = $tune->get_beat_sum;
    my $blueprint_bs = $tune_blueprint->get_beat_sum;
    printf "beatlengde før   fasit: %s, spilt: %s\n",$blueprint_bs,$play_bs;
    $tune->evaluate_with_blueprint($tune_blueprint);
    printf "\n\nSTART\nshortest_note_time %s, denominator %s\n",$tune->shortest_note_time,$tune->denominator;
    printf "Navn:          %s\n", color('blue') . decode('UTF-8',basename($tune_blueprint->name||$tune_blueprint->note_file) ) . color('reset');
    printf "Korteste note: %.2f\n", $tune->shortest_note_time;
    printf "Ny korteste note: %.2f\n", $new_shortest_note;
    printf "Beatinternval: %.2f\n", $tune->beat_interval;
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
    my $notes_dir = $self->curfile->dirname->sibling("notes");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");
    say $notes_dir->list_tree->map(sub{basename($_)})->join("\n");

    say '';
    say "blueprints/";
    say decode('utf8',$self->blueprints_dir->list_tree->map(sub{basename($_)})->join("\n"));
}

=head2 do_save

Save played tune to disk in local/notes directory as notes (txt)

=cut

sub do_save {
    my ($self, $tune, $name) = @_;
    return if !$name;
    $name .= '.txt' if ($name !~/\.midi?$/);
    my $new_file = $self->local_dir($self->blueprints_dir->child('notes'))->child($name);
    if (! $tune->name) {
        my $tname = $name;
        $tname=~ s/_/ /;
        $tname = uc(substr($tname,0,1)) . substr($tname,1);
        $tune->name($tname);
    }
    if (! $tune->hand_right_min) {
        $tune->hand_right_min('C4');
    }
    $new_file->spurt($tune->to_string);
    say "Saved $new_file";
}

=head2 do_save_midi

Save played tune as midi

=cut

sub do_save_midi {
    my ($self, $name) = @_;
    $name .= '.midi' if ($name !~/\.midi?$/);
    my $new_file = $self->local_dir($self->blueprints_dir->child('notes'))->child($name);
    $self->tune->to_midi_file($new_file);
    say "Saved $new_file";
}

=head2 get_blueprint_by_pathfile

Same as Music::Tune->from_note_file("$name");

=cut

sub get_blueprint_by_pathfile {
    my ($class,$name) = @_;
    return Music::Tune->from_note_file("$name");
}

=head2 get_pathfile_by_name

Return filepath for tune name part

=cut

sub get_pathfile_by_name {
    my ($self, $name) = @_;
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
                } else {
                   warn "$filename or ".$self->blueprints_dir->child($filename).", $lbf or regex $name not found.";
                   return;
                }
            }
        }
    }
    return $filename;
}

=head2 guess_blueprint

Return guessed blueprint based on played notes.

=cut

sub guess_blueprint {
    my $self = shift;
    my $tune = shift;
    if (@{$tune->notes} <10) {
        say "For kort låt for å sammenligne" if scalar @{$tune->notes};
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
#    return Music::Utils::Scale::value2notename($self->tune->scale,$note);
#}


1;
