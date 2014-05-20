use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;
use Path::Tiny;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Prereqs => { Switch => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.012' } ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] aborting\E/,
        'build aborted'
    );

    cmp_deeply(
        $tzil->log_messages,
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency that was deprecated from core in 5.011: Switch'),
        'Switch has been deprecated',
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Prereqs => { Switch => 0 } ],
                    [ OnlyCorePrereqs => { starting_version => '5.012', deprecated_ok => 1 } ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);

    is(
        exception { $tzil->build },
        undef,
        'build is not aborted',
    );

    ok(
        (!grep { /\[OnlyCorePrereqs\]/ } grep { !/\[OnlyCorePrereqs\] checking / } @{$tzil->log_messages}),
        'Switch has been deprecated, but that\'s ok!',
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;
}

done_testing;
