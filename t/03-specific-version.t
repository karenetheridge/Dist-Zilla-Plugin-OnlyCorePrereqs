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
                    [ Prereqs => RuntimeRequires => { 'HTTP::Tiny' => '0.025' } ],
                    [ OnlyCorePrereqs => { starting_version => '5.014' } ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] aborting\E/,
        'build aborted'
    );

    my $msgs = $tzil->log_messages;

    ok(grep({/\Q[OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny 0.025: perl 5.014 only has 0.012\E/} @$msgs),
        'HTTP::Tiny was in core in 5.014, but only at version 0.012 - plugin check fails',
    ) or diag explain $msgs;

}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'feature' => '1.33' } ],
                    [ OnlyCorePrereqs => { starting_version => 'current' } ],
                ),
            },
        },
    );

    # in 5.019000, feature has been upgraded from version 1.32 to 1.33.
    # feature is not dual-lifed, so we know the user hasn't upgraded.

    if ($^V < 5.019000)
    {
        like(
            exception { $tzil->build },
            qr/\Q[OnlyCorePrereqs] aborting\E/,
            'build aborted'
        );

        my $msgs = $tzil->log_messages;

        ok(grep({/\Q[OnlyCorePrereqs] detected a runtime requires dependency on feature 1.33: perl $^V only has \E\d\.\d+/} @$msgs),
            'version of perl is too old for feature 1.33 (need 5.019) - plugin check fails',
        );

    }
    else
    {
        is(
            exception { $tzil->build },
            undef,
            'version of perl is new enough for feature 1.33 (need 5.019) - plugin check succeeds',
        );
    }
}

SKIP:
{
    # Carp is dual-lifed, and was upgraded to 1.30 in 5.019000 -> 5.019001
    # The version of Module::CoreList that covers this change is 2.93
    skip 'this test requires a very recent Module::CoreList', 1
        unless Module::CoreList->VERSION ge '2.93';

    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'Carp' => '1.30' } ],
                    [ OnlyCorePrereqs => { starting_version => 'latest' } ],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'Carp is new enough in 5.019001 - plugin check succeeds',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'File::stat' => '0' } ],
                    [ OnlyCorePrereqs => ],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'File::stat is undef in 5.005, but good enough - plugin check succeeds',
    );
}

done_testing;
