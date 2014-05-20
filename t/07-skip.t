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
                    [ Prereqs => RuntimeRequires => { 'Foo' => 0, 'Bar' => 0 } ],
                    [ OnlyCorePrereqs => { skips => ['Foo'] } ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);

    is(
        exception { $tzil->build },
        undef,
        'build succeeded'
    )
    or diag 'saw log messages: ', explain $tzil->log_messages;

    cmp_deeply(
        \@checked,
        [ 'Bar' ],
        'skip option is respected',
    );
}

done_testing;
