package Model::Beat;
use Mojo::Base -base;
use Data::Dumper;
use Clone;

#  numerator and denominator

has number => 0;
has numerator => 0;
has denominator => 8;

use overload
    '""' => sub { shift->to_string }, fallback => 1,
    '+' => \&add,
    '-' => \&subtract,;


sub to_string {
  my $self = shift;
      return sprintf "%d.%d",$self->number,$self->numerator;
      # time, length,note
      # 3.8;1/4;C4
   
}

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

sub clone {
    my $self = shift;
    return Model::Beat->new(number => $self->number, numerator => $self->numerator, denominator => $self->denominator);
}

sub to_int {
	my $self =shift;
	return $self->numerator + $self->number * $self->denominator;
}
1;
