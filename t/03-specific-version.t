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
        qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny 0.025: perl 5.014 only has 0.012\E/,
        'HTTP::Tiny was in core in 5.014, but only at version 0.012 - plugin check fails',
    );
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
            qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency on feature 1.33: perl $^V only has \d\.\d+\E/,
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

done_testing;
