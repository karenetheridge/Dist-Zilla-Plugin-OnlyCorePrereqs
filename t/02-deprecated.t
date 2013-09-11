use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
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
        qr/\Q[OnlyCorePrereqs] aborting\E/,
        'build aborted'
    );

    cmp_deeply(
        $tzil->log_messages,
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency that was deprecated from core in 5.011: Switch'),
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
        'build is not aborted',
    );

    ok(
        (!grep { /\[OnlyCorePrereqs\]/ } @{$tzil->log_messages}),
        'Switch has been deprecated, but that\'s ok!',
    );
}

done_testing;
