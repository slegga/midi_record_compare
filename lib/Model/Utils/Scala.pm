package Model::Utils::Scala;
use Mojo::Base -strict;
use Scalar::Util qw(looks_like_number);

=head1 NAME

Model::Utils::Scala - converting from to scala and numbers

=head1 DESCRIPTION

Convert number to note name

=head1 METHODS


=head2 notename2value

For converting note_name to value.

Make scala object based on note name.

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

=head2 guess_scala

Takes array ref of notevalues.

Return scala name.

=cut

sub guess_scala {
    my $notes = shift;
    my %profile;
    for my  $n (@$notes) {
        $profile{$n % 12}++;
    }
    my %scales = (#  C D E F G A H
        'c_dur' =>  [0,2,4,5,7,9,11],
        'em_dur' => [0,2,3,5,7,8,10], #C, D, Eb, F, G, Ab, Bb, C
        'f_dur' =>  [0,2,4,5,7,9,10], # F, G, A, Bb, C, D, E, F
        'g_dur' =>  [0,2,4,6,7,9,11], # G, A, B, C, D, E, F#, G
        ''
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

Takes scalaname and a number for note and return note name.

=cut

sub value2notename {
    my $scala = shift//'c_dur';
    my $value = shift;
    die "Need a number" if ! looks_like_number($value);
    my $oct = int($value /12);
    return _bit_from_value($scala,$value % 12) . $oct;
}

#
#   Internal sub
#

# Return C for 0 Cs for 1 etc.

sub _bit_from_value {
    my $scala = shift;
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

    if (grep {$scala eq $_} (qw/em_dur cs_dur dm_dur/)) {
        return "Dm" if ($bit == 1) ;
        return "Em" if ($bit == 3) ;
        return "Gm" if ($bit == 6) ;
        return "Am" if ($bit == 8) ;
        return "Hm" if ($bit == 10) ;
    }

    if (grep {$scala eq $_} (qw/f_dur/)) {
        return "Hm" if ($bit == 10) ;
    }

    return $note_names{$bit};
}


1;