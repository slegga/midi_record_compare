use Test::More;
use Music::Utils::Scale;
is(Music::Utils::Scale::alter_notename('c_dur','C4',1),'Cs4','Alter works');
is(Music::Utils::Scale::alter_notename('c_dur','C4',-1),'H3','Alter works');

done_testing;
