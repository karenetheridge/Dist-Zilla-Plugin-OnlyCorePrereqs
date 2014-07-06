use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;
use Module::CoreList;
use Path::Tiny;
use List::Util 'first';

{
    # I've hit this a few times: I have a prereq of warnings, but I forgot to
    # set starting_version to 5.006, even if check_dual_life_versions is set.
    # It would be much nicer if we set the starting version automatically.
    # (Even better when the minimum perl version is automatically set based on
    # the presence of particular non-dual-lifed modules in the prereqs.)

    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Prereqs => RuntimeRequires => { warnings => 0 } ],    # warnings were added in 5.006
                    [ OnlyCorePrereqs => ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] aborting build due to invalid dependencies\E/,
        'build aborted',
    );

    cmp_deeply(
        $tzil->log_messages,
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency that was not added to core until 5.006: warnings'),
        'build failed -- perl 5.005 does not contain warnings (and it is not dual-lifed)'
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;

    is(
        (first { $_->plugin_name eq 'OnlyCorePrereqs' } @{$tzil->plugins})->starting_version,
        '5.005',
        'starting_version set to 5.005',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Prereqs => RuntimeRequires => {
                        warnings => 0,
                        perl => '5.006',
                      }
                    ],
                    [ OnlyCorePrereqs => ],
                ),
            },
        },
    );

    # normally we'd see this:
    # [OnlyCorePrereqs] detected a runtime requires dependency that was not added to core until 5.006: warnings
    is(
        exception { $tzil->build },
        undef,
        'build succeeded, despite warnings not being available in perl 5.005'
    );

    cmp_deeply(
        $tzil->log_messages,
        superbagof(re(qr/^\Q[DZ] writing DZT-Sample in /)),
        'build completed successfully',
    ) or diag 'saw log messages: ', explain $tzil->log_messages;

    is(
        (first { $_->plugin_name eq 'OnlyCorePrereqs' } @{$tzil->plugins})->starting_version,
        '5.006',
        'starting_version set to 5.006',
    );
}

done_testing;
