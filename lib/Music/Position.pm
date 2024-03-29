package Music::Position;
use Mojo::Base -base;
use Clone;

#  numerator and denominator
has integer =>0;
# has number => 0;
# has numerator => 0;
has denominator => 8;
has count_first =>1;

use overload
    '""' => sub { shift->to_string }, fallback => 1,
    '+' => \&add,
    '-' => \&subtract,;

=head1 NAME

Music::Position

=head1 SYNOPSIS

    use Music::Position;
    print Music::Position->new(integer=>35, denominator=>8) + 4;

=head1 DESCRIPTION

Beat object. number.part

=head1 METHODS

=head2 add

    my $new = $self->add(Music::Position->new(number=>1,numerator=>2,denominator=>4);

Add beats. Return new beat.

=cut

sub add {
    my ($self, $other,$swap) = @_;
	my $integer = $self->integer;
    #my $numerator = $self->numerator;
	if (ref $other eq __PACKAGE__ ) {
			$integer += $other->integer;
	} elsif($other=~/^\d+$/)	{
		$integer += $other;
	} elsif (! $other ) {
	    # do nothing
	} else {
		die ((ref $other//'') .' , '. ($other//'__UNDEF__'));
	}
#	 while ($numerator >= $self->denominator) {
#		$number++;
#        $numerator -= $self->denominator;
#	}
	return Music::Position->new(integer => $integer, denominator => $self->denominator, count_first => $self->count_first);
}

=head2 clone

Return a new similar beat with same values.

=cut

sub clone {
    my $self = shift;
    return Music::Position->new(integer => $self->integer, denominator => $self->denominator, count_first => $self->count_first);
}

=head2 subtract

Similar as add.

=cut

sub subtract {
  my ($self, $other,$swap) = @_;
  my $integer = $self->integer;
  if ($swap) {
		...;
	}
  if (ref $other eq __PACKAGE__ ) {
      $integer -= $other->integer;
  } elsif($other=~/^\d+$/)  {
    $integer -= $other;
  } else {
    die ref $other .'  '. $other;
  }
   #while ($numerator<0) {
#    $number--;
#        $numerator += $self->denominator;
#  }
  return Music::Position->new(integer => $integer, denominator => $self->denominator, count_first => $self->count_first);

}

=head2 to_string

Return beat as string with . as delimiter between beat and beat part

=cut

sub to_string {
    my $self = shift;
    my $number = int($self->integer/$self->denominator);
    my $numerator = $self->integer - $number * $self->denominator;
    return sprintf "%d.%d",$number + $self->count_first, $numerator;
      # time, length,note
      # 3.8;1/4;C4

}

=head2 to_int

Return As a number.

=cut

sub to_int {
	my $self =shift;
	return $self->integer;
}

1;
