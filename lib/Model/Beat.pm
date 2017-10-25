package Model::Beat;
use Mojo::Base -base;
use Data::Dumper;

has beat_no => 0;
has beat_part => 0;
har beat_size => 8;

use overload
    '""' => sub { shift->to_string }, fallback => 1,
    '+' => \&add,;

sub to_string {
  my $self = shift;
v  my $opts = shift;
  if ($opts) {
     my $p = $self->beat_part;
     my $s = $self->beat_size;
     if ($s % 3 == 0) {
        $s=4 * $s / 3
     }
     if ($p %2 == 0 && $s % 2 == 0) {
         $p = $p /2;
         $s = $s /2;
     }
     return sprintf "%d/%d",$p,$s;
  } else {
      return sprintf "%d.%d",$self->beat_no,$self->beat_part;
      # time, length,note
      # 3.8;1/4;C4
   
  }
}

sub add {
    my $self
}
1;
