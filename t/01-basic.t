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
                    [ Prereqs => RuntimeRequires => { Moose => 0 } ],
                    [ OnlyCorePrereqs => ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency that is not in core: Moose\E/,
        'Moose is not in core - plugin check fails',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { parent => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.010' } ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency that was not added to core until 5.010001: parent\E/,
        'parent was not in core in 5.10 - plugin check fails',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => { perl => '5.010' } ],
                    [ Prereqs => TestRequires => { parent => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.010', phase => [ 'runtime' ] } ],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'non-core modules are permitted in the test phase',
    );
}

done_testing;
