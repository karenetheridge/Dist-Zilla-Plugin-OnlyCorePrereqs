use strict;
use warnings;
package Dist::Zilla::Plugin::OnlyCorePrereqs;
# ABSTRACT: Check that no prerequisites are declared that are not part of core

use 5.010;
use Moose;
with 'Dist::Zilla::Role::AfterBuild';
use Moose::Util::TypeConstraints;
use Module::CoreList 2.77;
use MooseX::Types::Perl 0.101340 'LaxVersionStr';
use version;
use namespace::autoclean;

has phases => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { [ qw(runtime test) ] },
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
    default => '5.005',
);

has deprecated_ok => (
    is => 'ro', isa => 'Bool',
    default => 0,
);

has check_module_versions => (
    is => 'ro', isa => 'Bool',
    default => 1,
);

sub mvp_multivalue_args { qw(phases) }
sub mvp_aliases { { phase => 'phases' } }

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
            $self->log_debug("checking $prereq");

            my $added_in = Module::CoreList->first_release($prereq);

            if (not defined $added_in)
            {
                push @non_core, [$phase, $prereq];
                next;
            }

            if (version->parse($added_in) > $self->starting_version)
            {
                push @not_yet, [$phase, $added_in, $prereq];
                next;
            }

            if ($self->check_module_versions)
            {
                my $has = $Module::CoreList::version{$self->starting_version->numify}{$prereq};
                $has = version->parse($has);    # version.pm XS hates tie() - RT#87983
                my $wanted = version->parse($prereqs->{$phase}{requires}{$prereq});

                if ($has < $wanted)
                {
                    push @insufficient_version, [ map { "$_" } $phase, $prereq, $wanted, $self->starting_version, $has ];
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

=over 4

=item * C<phase>

Indicates a phase to check against. Can be provided more than once; defaults
to C<runtime> and C<test>.  (See L<Dist::Zilla::Plugin::Prereqs> for more
information about phases.)

Remember that you can use different settings for different phases by employing
this plugin twice, with different names.

=item * C<starting_version>

Indicates the first Perl version that should be checked against; any versions
earlier than this are not considered significant for the purposes of core
checks.  Defaults to C<5.005>.

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

=item * C<deprecated_ok>

A boolean flag indicating whether it is considered acceptable to depend on a
deprecated module. Defaults to 0.

=item * C<check_module_versions>

A boolean flag indicating whether the specific module version available in the
C<starting_version> of perl should also be checked.  Defaults to 1.

(For example, a prerequisite of L<Test::More> 0.88  at C<starting_version>
5.010 would fail with C<check_module_versions> set, as the version of
L<Test::More> that shipped with that version of perl was only 0.72.

=back

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-OnlyCorePrereqs>
(or L<bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
