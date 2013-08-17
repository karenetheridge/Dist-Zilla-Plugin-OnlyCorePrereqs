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

done_testing;
