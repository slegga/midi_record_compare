package Model::Scala;
use Mojo::Base -base;
use Scalar::Util qw(looks_like_number);
use overload
    '""' => sub { shift->to_string }, fallback => 1,



has scala =>'c_dur';
has value => undef;

sub p {
    return shift->to_string(shift);
}

sub to_string {
    my $self = shift;
    my $value = shift;
    $value = $self if !defined $value;
    die "Need a number" if ! looks_like_number($value);
    my $return = '_from_'.$self->scala;
    my $oct = int($value /12);
    return $self->$return($value % 12) . $oct;
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
1;
