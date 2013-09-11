use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;


#find a case where module version check would fail
#see no eception.

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'HTTP::Tiny' => '0.025' } ],
                    [ OnlyCorePrereqs => { starting_version => '5.014', check_module_versions => 0 } ],
                ),
            },
        },
    );

    # normally we'd see this:
    # [OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny
    # 0.025: perl 5.014 only has 0.012
    is (
        exception { $tzil->build },
        undef,
        'build succeeded, despite HTTP::Tiny not at 0.025 in perl 5.014'
    );
}

done_testing;
