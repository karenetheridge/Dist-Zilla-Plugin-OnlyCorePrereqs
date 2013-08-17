use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings;
use Test::Fatal;
use Test::DZil;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => { Switch => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.012' } ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency that was deprecated from core in 5.011: Switch\E/,
        'Switch has been deprecated',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => { Switch => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.012', deprecated_ok => 1 } ],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'Switch has been deprecated, but that\'s ok!',
    );
}

done_testing;
