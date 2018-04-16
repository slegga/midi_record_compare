package Model::Scala;
use Mojo::Base -base;
use Scalar::Util qw(looks_like_number);
use overload
    '""' => sub { shift->to_string }, fallback => 1,;

=head1 NAME

Model::Scala

=head1 DESCRIPTION

Convert number to note name

=head1 METHODS

=cut

has scala =>'c_dur';
has value => undef;  #note as a number

=head2 from_notename

For converting note_name to value.

Make scala object based on note name.

=cut

sub from_notename {
    my $class = shift;
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
        "Bs" =>10,
        "H"  =>11,
        "B"  =>11,
        );
    die "Bad name $notename $name $oct" if !exists $note_names{$name};
    return $class->new(value => $note_names{$name} + $oct * 12);
}

=head2 p

Short for to_string

=cut

sub p {
    return shift->to_string(shift);
}

=head2 to_string

Takes a number for note and return note name.

=cut

sub to_string {
    my $self = shift;
    my $value = shift;
    if (!defined $value) {
        $value = $self->value;
    }
    die "Need a number" if ! looks_like_number($value);
    my $return = '_from_'.$self->scala;
    my $oct = int($value /12);
    return $self->$return($value % 12) . $oct;
}

sub _from_a_mol {
    return shift->_from_c_dur(shift);
}

sub _from_c_dur {
    my $self=shift;
    my $bit=shift;
    my %note_names =(
        0 =>    "C",
        1 =>    "Cs",
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
    return $note_names{$bit};
}

sub _from_c_mol {
    return shift->_from_em_mol(shift);
}

sub _from_em_mol {
    my $self=shift;
    my $bit=shift;
    my %note_names =(
        0 =>    "C",
        1 =>    "Dm",
        2 =>    "D",
        3 =>    "Em",
        4 =>    "E",
        5 =>    "F",
        6 =>    "Fs",
        7 =>    "G",
        8 =>    "Am",
        9 =>    "A",
        10 =>   "Hm",
        11 =>   "H",);
    return $note_names{$bit};
}

1;
