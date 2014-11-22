use strict;
use warnings;
package Dist::Zilla::Plugin::OnlyCorePrereqs;
# ABSTRACT: Check that no prerequisites are declared that are not part of core
# KEYWORDS: plugin distribution metadata prerequisites core
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with 'Dist::Zilla::Role::AfterBuild';
use Moose::Util::TypeConstraints;
use Module::CoreList 3.10;
use MooseX::Types::Perl 0.101340 'LaxVersionStr';
use version;
use HTTP::Tiny;
use JSON::MaybeXS;
use CPAN::Meta::Requirements 2.121;
use namespace::autoclean;

has phases => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { [ qw(configure build runtime test) ] },
    traits => ['Array'],
    handles => { phases => 'elements' },
);

has starting_version => (
    is => 'ro',
    isa => do {
        my $version = subtype as class_type('version');
        coerce $version, from LaxVersionStr, via { version->parse($_) };
        $version;
    },
    coerce => 1,
    predicate => '_has_starting_version',
    lazy => 1,
    default => sub {
        my $self = shift;

        my $prereqs = $self->zilla->distmeta->{prereqs};
        my @perl_prereqs = grep { defined } map { $prereqs->{$_}{requires}{perl} } keys %$prereqs;

        return '5.005' if not @perl_prereqs;

        my $req = CPAN::Meta::Requirements->new;
        $req->add_minimum(perl => $_) foreach @perl_prereqs;
        $req->requirements_for_module('perl');
    },
);

has deprecated_ok => (
    is => 'ro', isa => 'Bool',
    default => 0,
);

has check_dual_life_versions => (
    is => 'ro', isa => 'Bool',
    default => 1,
);

has skips => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => {
        skips => 'elements',
        skip_module => 'grep',
    },
    lazy => 1,
    default => sub { [] },
);

sub mvp_multivalue_args { qw(phases skips) }
sub mvp_aliases { { phase => 'phases', skip => 'skips' } }

around BUILDARGS => sub
{
    my $orig = shift;
    my $self = shift;

    my $args = $self->$orig(@_);

    if (($args->{starting_version} // '') eq 'current')
    {
        $args->{starting_version} = $^V;
    }
    elsif (($args->{starting_version} // '') eq 'latest')
    {
        # needs to be two clauses because of version.pm: RT#87983
        my $latest = (reverse sort keys %Module::CoreList::released)[0];
        $args->{starting_version} = version->parse($latest);
    }

    $args;
};

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        ( map { $_ => [ $self->$_ ] } qw(phases skips)),
        ( map { $_ => $self->$_ } qw(deprecated_ok check_dual_life_versions)),
        ( starting_version => ($self->_has_starting_version ? $self->starting_version : 'to be determined from perl prereq')),
    };

    return $config;
};

sub after_build
{
    my $self = shift;

    my $prereqs = $self->zilla->distmeta->{prereqs};

    # we build up a lists of all errors found
    my (@non_core, @not_yet, @insufficient_version, @deprecated);

    foreach my $phase ($self->phases)
    {
        foreach my $prereq (keys %{ $prereqs->{$phase}{requires} // {} })
        {
            next if $prereq eq 'perl';

            if ($self->skip_module(sub { $_ eq $prereq })) {
                $self->log_debug([ 'skipping %s', $prereq ]);
                next;
            }

            $self->log_debug([ 'checking %s', $prereq ]);
            my $added_in = Module::CoreList->first_release($prereq);

            if (not defined $added_in)
            {
                push @non_core, [$phase, $prereq];
                next;
            }

            if (version->parse($added_in) > $self->starting_version
                and ($self->check_dual_life_versions or not $self->_is_dual($prereq)))
            {
                push @not_yet, [$phase, $added_in, $prereq];
                next;
            }

            if ($self->check_dual_life_versions or not $self->_is_dual($prereq))
            {
                my $has = $Module::CoreList::version{$self->starting_version->numify}{$prereq};
                $has = version->parse($has);    # version.pm XS hates tie() - RT#87983
                my $wanted = version->parse($prereqs->{$phase}{requires}{$prereq});

                if ($has < $wanted)
                {
                    push @insufficient_version, [ map { "$_" } $phase, $prereq, $wanted, $self->starting_version->numify, $has ];
                    next;
                }
            }

            if (not $self->deprecated_ok)
            {
                my $deprecated_in = Module::CoreList->deprecated_in($prereq);
                if ($deprecated_in)
                {
                    push @deprecated, [$phase, $deprecated_in, $prereq];
                    next;
                }
            }
        }
    }

    $self->log(['detected a %s requires dependency that is not in core: %s', @$_])
        for @non_core;

    $self->log(['detected a %s requires dependency that was not added to core until %s: %s', @$_])
        for @not_yet;

    $self->log(['detected a %s requires dependency on %s %s: perl %s only has %s', @$_])
        for @insufficient_version;

    $self->log(['detected a %s requires dependency that was deprecated from core in %s: %s', @$_])
        for @deprecated;

    $self->log_fatal('aborting build due to invalid dependencies')
        if @non_core || @not_yet || @insufficient_version || @deprecated;
}

# this will get easier if we can just ask MCL for this information, rather
# than guessing.
sub _is_dual
{
    my ($self, $module) = @_;

    my $upstream = $Module::CoreList::upstream{$module};
    $self->log_debug([ '%s is upstream=%s', $module, sub { $upstream // 'undef' } ]);
    return 1 if defined $upstream and ($upstream eq 'cpan' or $upstream eq 'first-come');

    # if upstream=blead or =undef, we can't be sure if it's actually dual or
    # not, so for now we'll have to ask the index and hope that the
    # 'no_index' entries in the last perl release were complete.
    # TODO: keep checking Module::CoreList for fixes.
    my $dist_name = $self->_indexed_dist($module);
    $self->log_debug([ '%s is indexed in the %s dist', $module, sub { $dist_name // 'undef' } ]);
    return 0 if not defined $dist_name or $dist_name eq 'perl';
    return 1;
}


# if only the index were cached somewhere locally that I could query...
sub _indexed_dist
{
    my ($self, $module) = @_;

    my $res = HTTP::Tiny->new->get("http://cpanidx.org/cpanidx/json/mod/$module");
    $self->log_debug('could not query the index?'), return undef if not $res->{success};

    my $payload = JSON::MaybeXS->new(utf8 => 0)->decode($res->{content});

    $self->log_debug('invalid payload returned?'), return undef unless $payload;
    $self->log_debug([ '%s not indexed', $module ]), return undef if not defined $payload->[0]{dist_name};
    return $payload->[0]{dist_name};
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [OnlyCorePrereqs]
    starting_version = 5.010

=head1 DESCRIPTION

C<[OnlyCorePrereqs]> is a L<Dist::Zilla> plugin that checks at build time if
you have any declared prerequisites that are not shipped with Perl.

You can specify the first Perl version to check against, and which
prerequisite phase(s) are significant.

If the check fails, the build is aborted.

=for Pod::Coverage after_build mvp_aliases mvp_multivalue_args

=head1 OPTIONS

=head2 C<phase>

Indicates a phase to check against. Can be provided more than once; defaults
to C<configure>, C<build>, C<runtime>, C<test>.  (See L<Dist::Zilla::Plugin::Prereqs> for more
information about phases.)

Remember that you can use different settings for different phases by employing
this plugin twice, with different names.

=head2 C<starting_version>

Indicates the first Perl version that should be checked against; any versions
earlier than this are not considered significant for the purposes of core
checks.  Defaults to the minimum version of perl declared in the distribution's
prerequisites, or C<5.005>.

There are two special values supported:

=begin :list

=item * C<current> - indicates the version of Perl that you are currently running with

=item * C<latest> - indicates the most recent (stable or development) release of Perl

=end :list

(Note: if you wish to check against B<all> changes in core up to the very
latest Perl release, you should upgrade your L<Module::CoreList> installation.
You can guarantee you are always running the latest version with
L<Dist::Zilla::Plugin::PromptIfStale>. L<Module::CoreList> is also the mechanism used for
determining the version of the latest Perl release.)

=head2 C<deprecated_ok>

A boolean flag indicating whether it is considered acceptable to depend on a
deprecated module. Defaults to 0.

=head2 C<check_dual_life_versions>

=for stopwords lifed blead

A boolean flag indicating whether the specific module version available in the
C<starting_version> of perl be checked (even) if the module is dual-lifed.
Defaults to 1.

This is useful to B<unset> if you don't want to fail if you require a core module
that the user can still upgrade via the CPAN, but do want to fail if the
module is B<only> available in core.

Note that at the moment, the "is this module dual-lifed?" heuristic is not
100% reliable, as we may need to interrogate the PAUSE index to see if the
module is available outside of perl -- which can generate a false negative if
the module is upstream-blead and there was a recent release of a stable perl.
This is hopefully going to be rectified soon (when I add the necessary feature
to L<Module::CoreList>).

(For example, a prerequisite of L<Test::More> 0.88 at C<starting_version>
5.010 would fail with C<check_dual_life_versions = 1>, as the version of
L<Test::More> that shipped with that version of perl was only 0.72,
but not fail if C<check_dual_life_versions = 0>.

=head2 C<skip>

The name of a module to exempt from checking. Can be used more than once.

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-OnlyCorePrereqs>
(or L<bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
