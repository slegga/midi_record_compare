package Model::Beat;
use Mojo::Base -base;
use Clone;

#  numerator and denominator

has number => 0;
has numerator => 0;
has denominator => 8;

use overload
    '""' => sub { shift->to_string }, fallback => 1,
    '+' => \&add,
    '-' => \&subtract,;

=head1 NAME

Model::Beat

=head1 DESCRIPTION

Beat object. number.part

=head1 METHODS

=head2 add

my $new = $self->add(Model::Beat->new(number=>1,numerator=>2,denominator=>4);

Add beats. Retutn new beat.

=cut

sub add {
  my ($self, $other,$swap) = @_;
	my $number = $self->number;
  my $numerator = $self->numerator;
	if (ref $other eq __PACKAGE__ ) {
			$number += $other->number;
			$numerator += $other->numerator;
	} elsif($other=~/^\d+$/)	{
		$numerator += $other;
	} else {
		die ref $other .'  '. $other;
	}
	 while ($numerator>=$self->denominator) {
		$number++;
        $numerator -= $self->denominator;
	}
	return Model::Beat->new(number => $number, numerator => $numerator, denominator => $self->denominator);
}

=head2 clone

Return a new similar beat with same values.

=cut

sub clone {
    my $self = shift;
    return Model::Beat->new(number => $self->number, numerator => $self->numerator, denominator => $self->denominator);
}

=head2 subtract

Similar as add.

=cut

sub subtract {
  my ($self, $other,$swap) = @_;
  my $number = $self->number;
  my $numerator = $self->numerator;
	if ($swap) {
		...;
	}
  if (ref $other eq __PACKAGE__ ) {
      $number -= $other->number;
      $numerator -= $other->numerator;
  } elsif($other=~/^\d+$/)  {
    $numerator -= $other;
  } else {
    die ref $other .'  '. $other;
  }
   while ($numerator<0) {
    $number--;
        $numerator += $self->denominator;
  }
  return Model::Beat->new(number => $number, numerator => $numerator, denominator => $self->denominator);

}

=head2 to_string

Return beat as string with . as delimiter between beat and beat part

=cut

sub to_string {
  my $self = shift;
      return sprintf "%d.%d",$self->number,$self->numerator;
      # time, length,note
      # 3.8;1/4;C4

}

=head2 to_int

Return As a number.

=cut

sub to_int {
	my $self =shift;
	return $self->numerator + $self->number * $self->denominator;
}

1;
