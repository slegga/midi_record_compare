# script_compile.t
use Test2::V0;
use Test::Script;
use Mojo::File 'path';
for my $script (glob('script/*'),glob('bin/*')) { #$FindBin::Bin . '/../
    next if -d $script;
    next if ( $script !~ /\.pl$/ && $script !~ /^[^\.]+$/);
    $script= path $script;
    next if $script->slurp !~ /use SH\:\:ScriptX\;/;
    script_runs(["$script", '--help']);
}
done_testing;