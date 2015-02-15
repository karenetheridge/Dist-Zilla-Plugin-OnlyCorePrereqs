use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;
use Module::CoreList;
use Path::Tiny;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ MetaConfig => ],
                    [ Prereqs => RuntimeRequires => { 'HTTP::Tiny' => '0.025' } ],
                    [ OnlyCorePrereqs => { starting_version => '5.014' } ],
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
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny 0.025: perl 5.014 only has 0.012'),
        'HTTP::Tiny was in core in 5.014, but only at version 0.012 - check fails',
    ) or diag 'saw log messages: ', explain $tzil->log_messages;

    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    {
                        class => 'Dist::Zilla::Plugin::OnlyCorePrereqs',
                        config => {
                            'Dist::Zilla::Plugin::OnlyCorePrereqs' => {
                                skips => [],
                                phases => bag('configure', 'build', 'runtime', 'test'),
                                starting_version => '5.014',
                                deprecated_ok => 0,
                                check_dual_life_versions => 1,
                            },
                        },
                        name => 'OnlyCorePrereqs',
                        version => ignore,
                    },
                ),
            })
        }),
        'config is properly included in metadata',
    ) or diag 'got dist metadata: ', explain $tzil->distmeta;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ MetaConfig => ],
                    [ Prereqs => RuntimeRequires => { 'feature' => '1.33' } ],
                    [ OnlyCorePrereqs => { starting_version => 'current' } ],
                ),
            },
        },
    );

    # in 5.019000, feature has been upgraded from version 1.32 to 1.33.
    # feature is not dual-lifed, so we know the user hasn't upgraded.

    if ($] < 5.019000)
    {
        $tzil->chrome->logger->set_debug(1);

        like(
            exception { $tzil->build },
            qr/\Q[OnlyCorePrereqs] aborting\E/,
            'build aborted'
        );

        # this dist requires 5.010, so we know feature is available at *some*
        # version (it first appeared in 5.9.3)

        cmp_deeply(
            $tzil->log_messages,
            supersetof(re(qr/\Q[OnlyCorePrereqs] detected a runtime requires dependency on feature 1.33: perl $] only has \E\d\.\d+/)),
            'version of perl is too old for feature 1.33 (need 5.019) - check fails',
        ) or do {
            # we have some odd failing reports:
            # http://www.cpantesters.org/cpan/report/e7624cf8-1bca-11e3-8778-8bb49a6ffe4e
            # http://cpantesters.org/cpan/report/5c8ff79f-6e70-1014-86e8-8333ec4105d1
            diag 'saw log messages: ', explain $tzil->log_messages;
            my $version = version->parse($^V)->numify;
            diag('corelist data for feature at version ', $version, ': ', $Module::CoreList::version{$version}{feature});
        };
    }
    else
    {
        is(
            exception { $tzil->build },
            undef,
            'build is not aborted',
        );

        ok(
            (!grep { /\[OnlyCorePrereqs\]/ } grep { !/\[OnlyCorePrereqs\] checking / } @{$tzil->log_messages}),
            'version of perl is new enough for feature 1.33 (need 5.019) - check succeeds',
        )
        or diag 'saw log messages: ', explain $tzil->log_messages;
    }

    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    {
                        class => 'Dist::Zilla::Plugin::OnlyCorePrereqs',
                        config => {
                            'Dist::Zilla::Plugin::OnlyCorePrereqs' => {
                                skips => [],
                                phases => bag('configure', 'build', 'runtime', 'test'),
                                starting_version => re(qr/[\d.]+/),
                                deprecated_ok => 0,
                                check_dual_life_versions => 1,
                            },
                        },
                        name => 'OnlyCorePrereqs',
                        version => ignore,
                    },
                ),
            })
        }),
        'config is properly included in metadata',
    ) or diag 'got dist metadata: ', explain $tzil->distmeta;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

SKIP:
{
    # Carp is dual-lifed, and was upgraded to 1.30 in 5.019000 -> 5.019001
    # The version of Module::CoreList that covers this change is 2.93
    skip 'this test requires a very recent Module::CoreList', 1
        unless Module::CoreList->VERSION ge '2.93';

    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ MetaConfig => ],
                    [ Prereqs => RuntimeRequires => { 'Carp' => '1.30' } ],
                    [ OnlyCorePrereqs => { starting_version => 'latest' } ],
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
        'Carp is new enough in 5.019001 - check succeeds',
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;

    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    {
                        class => 'Dist::Zilla::Plugin::OnlyCorePrereqs',
                        config => {
                            'Dist::Zilla::Plugin::OnlyCorePrereqs' => {
                                skips => [],
                                phases => bag('configure', 'build', 'runtime', 'test'),
                                starting_version => re(qr/[\d.]+/),
                                deprecated_ok => 0,
                                check_dual_life_versions => 1,
                            },
                        },
                        name => 'OnlyCorePrereqs',
                        version => ignore,
                    },
                ),
            })
        }),
        'config is properly included in metadata',
    ) or diag 'got dist metadata: ', explain $tzil->distmeta;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ MetaConfig => ],
                    [ Prereqs => RuntimeRequires => { 'File::stat' => '0' } ],
                    [ OnlyCorePrereqs => ],
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

    cmp_deeply(
        $tzil->distmeta,
        superhashof({
            x_Dist_Zilla => superhashof({
                plugins => supersetof(
                    {
                        class => 'Dist::Zilla::Plugin::OnlyCorePrereqs',
                        config => {
                            'Dist::Zilla::Plugin::OnlyCorePrereqs' => {
                                skips => [],
                                phases => bag('configure', 'build', 'runtime', 'test'),
                                starting_version => 'to be determined from perl prereq',
                                deprecated_ok => 0,
                                check_dual_life_versions => 1,
                            },
                        },
                        name => 'OnlyCorePrereqs',
                        version => ignore,
                    },
                ),
            })
        }),
        'config is properly included in metadata',
    ) or diag 'got dist metadata: ', explain $tzil->distmeta;

    ok(
        (!grep { /\[OnlyCorePrereqs\]/ } grep { !/\[OnlyCorePrereqs\] checking / } @{$tzil->log_messages}),
        'File::stat is undef in 5.005, but good enough - check succeeds',
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;
