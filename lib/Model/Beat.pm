package Model::Beat;
use Mojo::Base -base;
use Data::Dumper;

has beat_no => 0;
has beat_part => 0;
has beat_size => 8;

use overload
    '""' => sub { shift->to_string }, fallback => 1,
    '+' => \&add,;


sub to_string {
  my $self = shift;
      return sprintf "%d.%d",$self->beat_no,$self->beat_part;
      # time, length,note
      # 3.8;1/4;C4
   
}

sub add {
  my ($self, $other,$swap) = @_;;
	my $beat_no = $self->beat_no;
  my $beat_part = $self->beat_part;
	if (ref $other eq __PACKAGE__ ) {
			$beat_no += $other->beat_no;
			$beat_part += $other->beat_part;
	} elsif($other=~/^\d+$/)	{
		$beat_part += $other;
	} else {
		die ref $other .'  '. $other;
	}
	if ($beat_part>$self->beat_size) {
		...;
	}
	return Model::Beat
}
1;
