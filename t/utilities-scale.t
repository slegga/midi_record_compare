use Test::More;
use Model::Utils::Scale;
is(Model::Utils::Scale::alter_notename('c_dur','C4',1),'Cs4','Alter works');
is(Model::Utils::Scale::alter_notename('c_dur','C4',-1),'H3','Alter works');

done_testing;