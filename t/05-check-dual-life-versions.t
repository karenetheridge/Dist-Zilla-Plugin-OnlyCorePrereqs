use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;
use Moose::Util 'find_meta';

use Dist::Zilla::Plugin::OnlyCorePrereqs;   # make sure we are loaded!

{
    my $meta = find_meta('Dist::Zilla::Plugin::OnlyCorePrereqs');
    $meta->make_mutable;
    $meta->add_around_method_modifier(_indexed_dist => sub {
        my $orig = shift;
        my $self = shift;
        my ($module) = @_;

        return 'HTTP-Tiny' if $module eq 'HTTP::Tiny';
        return undef if $module eq 'feature';
        die 'should not be checking for ' . $module;
    });
}


{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'HTTP::Tiny' => '0.025' } ],
                    [ OnlyCorePrereqs => { starting_version => '5.014', check_dual_life_versions => 0 } ],
                ),
            },
        },
    );

    # normally we'd see this:
    # [OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny
    # 0.025: perl 5.014 only has 0.012
    is(
        exception { $tzil->build },
        undef,
        'build succeeded, despite HTTP::Tiny not at 0.025 in perl 5.014'
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'HTTP::Tiny' => '0.025' } ],
                    # check_dual_life_versions defaults to true
                    [ OnlyCorePrereqs => { starting_version => '5.014' } ],
                ),
            },
        },
    );

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] aborting build due to invalid dependencies\E/,
        'build aborted'
    );

    cmp_deeply(
        $tzil->log_messages,
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency on HTTP::Tiny 0.025: perl 5.014 only has 0.012'),
        'build failed -- HTTP::Tiny not at 0.025 in perl 5.014'
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/corpus/basic' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Prereqs => RuntimeRequires => { 'feature' => '1.33' } ],
                    [ OnlyCorePrereqs => { starting_version => '5.010000', check_dual_life_versions => 0 } ],
                ),
            },
        },
    );

    # feature existed in 5.010, but not at the version we are asking for
    # feature is not dual-lifed, so we know the user hasn't upgraded.

    like(
        exception { $tzil->build },
        qr/\Q[OnlyCorePrereqs] aborting build due to invalid dependencies\E/,
        'build aborted'
    );

    cmp_deeply(
        $tzil->log_messages,
        supersetof('[OnlyCorePrereqs] detected a runtime requires dependency on feature 1.33: perl 5.010000 only has 1.11'),
        'build failed -- feature not at this version in perl 5.010'
    ) or diag explain $tzil->log_messages;
}

done_testing;
