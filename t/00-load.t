use Test::More;
use FindBin;
use lib 'lib';
plan skip_all => 'Devel::Cover' if $ENV{HARNESS_PERL_SWITCHES} and $ENV{HARNESS_PERL_SWITCHES} =~ /Devel::Cover/;
eval 'use Test::Compile; 1' or plan skip_all => 'Test::Compile required';
all_pm_files_ok();

