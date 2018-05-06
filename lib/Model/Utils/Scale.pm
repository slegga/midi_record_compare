package Model::Utils::Scale;
use Mojo::Base -strict;
use Scalar::Util qw(looks_like_number);
use Carp::Always;

=head1 NAME

Model::Utils::Scale - converting from to scale and numbers

=head1 DESCRIPTION

Convert number to note name

=head1 METHODS


=head2 notename2value

For converting note_name to value.

Make scale object based on note name.

=cut

sub notename2value {
    my $notename = shift;
    my ($name,$oct) = ($notename =~ /(\w+)(\d+)/);
    my %note_names =(
        "C"  => 0,
        "Cs" => 1,
        "Dm" => 1,
        "D"  => 2,
        "Ds" => 3,
        "Em" => 3,
        "E"  => 4,
        "F"  => 5,
        "Fs" => 6,
        "Gm" => 6,
        "G"  => 7,
        "Gs" => 8,
        "Am" => 8,
        "A"  => 9,
        "As" =>10,
        "Hm" =>10,
        "Bm" =>10,
        "H"  =>11,
        "B"  =>11,
        );
    die "Bad name $notename $name $oct" if !exists $note_names{$name};
    return $note_names{$name} + $oct * 12;
}

=head2 guess_scale

Takes array ref of notevalues.

Return scale name.

=cut

sub guess_scale_from_notes {
    my $notes = shift;
    my %profile= map{$_,0} 0..11; # put 0 al over
    for my  $n (@$notes) {
        my $value=$n;
        $value =~ s/\s+\#.*//;          # remove commments
        $value =~ s/^.*\;//;            # remove extra info
        $value = notename2value($value); # text to numbers
        $profile{$value % 12}++;
    }
    my %scales = (
        'c_dur' =>  [0,2,4,5,7,9,11], #c, D, E,  F, G, A,  H
        'em_dur' => [0,2,3,5,7,8,10], #C, D, Eb, F, G, Ab, Hb, C
    );
    my $best='';
    my $best_score=0;
    for my $k (keys %scales) {
        my $score=0;
        for my $v (@{$scales{$k}}) {
            $score += $profile{$v};
        }
        if ($score>$best_score) {
            $best = $k;
            $best_score = $score;
        }
    }
    return $best;
}


=head2 value2notename

Takes scalename and a number for note and return note name.

=cut

sub value2notename {
    my $scale = shift//'c_dur';
    my $value = shift;
    die "Need a number" if ! looks_like_number($value);
    my $oct = int($value /12);
    return _bit_from_value($scale,$value % 12) . $oct;
}

#
#   Internal sub
#

# Return C for 0 Cs for 1 etc.

sub _bit_from_value {
    my $scale = shift;
    my $bit=shift;
    my %note_names =(
        0 =>    "C",
        1 =>    "Cs" ,
        2 =>    "D",
        3 =>    "Ds",
        4 =>    "E",
        5 =>    "F",
        6 =>    "Fs",
        7 =>    "G",
        8 =>    "Gs",
        9 =>    "A",
        10 =>   "As",
        11 =>   "H",);

        if (grep {$scale eq $_} (qw/em_mol c_mol/)) {
            return "Dm" if ($bit == 1) ;
            return "Em" if ($bit == 3) ;
            return "Gm" if ($bit == 6) ;
            return "Am" if ($bit == 8) ;
            return "Hm" if ($bit == 10) ;
        }
    return $note_names{$bit};
}


1;
