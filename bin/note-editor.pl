#!/usr/bin/env perl
#use Mojo::Base -strict;
use Term::Screen;

my $scr = new Term::Screen;

$scr->clrscr();
$a=$scr->getch();
print $a," ",length $a," ",ord($a),"\n";
#$scr->two_esc;
$a=$scr->getch();
print $a," ",length $a," ",ord($a),"\n";
#$scr->one_esc;


$scr->clrscr();
$scr->at(4,4)->puts("input? ");
#$line=$scr->readline(ROW => 4, COL => 12);
#$line=$scr->readline(ROW => 5, COL => 12, DISPLAYLEN => 20);
$scr->at(10,4)->puts($line);
#$scr->two_esc;
#$line=$scr->readline(ROW => 6, COL => 12, DISPLAYLEN => 20, ONLYVALID => "[ieIE]+", CONVERT => "up");

print "\n";
# print $scr->lastkey(),"\n";

$r=$scr->getch();
print $r,ord($r),"\n";
$r=ord($r);
print $r,"\n";
if ($r eq 13) {
  print "aja!\n";
}
