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
    my $self=shift;
    my $value=shift;
   ...; 
}
1;
