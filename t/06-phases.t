use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;
use Path::Tiny;
use Moose::Util 'find_meta';

my @checked;
{
    use Module::CoreList;
    package Module::CoreList;
    no warnings 'redefine';
    sub first_release {
        my ($self, $module) = @_;
        push @checked, $module;
        return '5';  # pretend everything is in core
    }
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    (map {
                        my $type = $_;
                        map {
                            my $phase = $_;
                            [ Prereqs => ($phase . $type) => { "Prereq::${phase}::${type}" => '0' } ],
                        } qw(Configure Build Runtime Test Develop)
                    } qw(Requires Recommends Suggests Conflicts)),
                    [ OnlyCorePrereqs => ],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'build succeeded'
    );

    cmp_bag(
        \@checked,
        [ qw(
            Prereq::Configure::Requires
            Prereq::Build::Requires
            Prereq::Runtime::Requires
            Prereq::Test::Requires
        ) ],
        'correct phases and types are checked by default',
    );
}

undef @checked;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    (map {
                        my $type = $_;
                        map {
                            my $phase = $_;
                            [ Prereqs => ($phase . $type) => { "Prereq::${phase}::${type}" => '0' } ],
                        } qw(Configure Build Runtime Test Develop)
                    } qw(Requires Recommends Suggests Conflicts)),
                    [ OnlyCorePrereqs => { phase => [qw(develop)] }],
                ),
            },
        },
    );

    is(
        exception { $tzil->build },
        undef,
        'build succeeded'
    );

    cmp_bag(
        \@checked,
        [ qw(
            Prereq::Develop::Requires
        ) ],
        '"phase" option can be customized',
    );
}

done_testing;
