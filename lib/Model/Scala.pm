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
has value => undef;


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
    $value = $self if !defined $value;
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
