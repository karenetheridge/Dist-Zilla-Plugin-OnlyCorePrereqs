use strict;
use warnings;
package Dist::Zilla::Plugin::OnlyCorePrereqs;
# ABSTRACT: Check that no prerequisites are declared that are not part of core

use Moose;
with 'Dist::Zilla::Role::AfterBuild';
use Moose::Util::TypeConstraints;
use Module::CoreList;
use MooseX::Types::Perl 0.101340 'LaxVersionStr';
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
        my $version_string = subtype as 'Str',
            where { LaxVersionStr->check( $_ ) },
            message { 'starting_version must be in a valid version format - see version.pm' };
        my $version = subtype as $version_string;
        coerce $version, from $version_string, via { version->parse($_) };
        $version;
    },
    coerce => 1,
    default => '5.005',
);

has deprecated_ok => (
    is => 'ro', isa => 'Bool',
    default => 0,
);

sub mvp_multivalue_args { qw(phases) }
sub mvp_aliases { { phase => 'phases' } }

sub after_build
{
    my $self = shift;

    my $prereqs = $self->zilla->distmeta->{prereqs};

    foreach my $phase ($self->phases)
    {
        foreach my $prereq (keys %{ $prereqs->{$phase}{requires} || {} })
        {
            next if $prereq eq 'perl';
            $self->log_debug("checking $prereq");

            my $added_in = Module::CoreList->first_release($prereq);

            $self->log_fatal('detected a ' . $phase
                . ' requires dependency that is not in core: ' . $prereq)
                    if not defined $added_in;

            $self->log_fatal('detected a ' . $phase
                . ' requires dependency that was not added to core until '
                . $added_in . ': ' . $prereq)
                    if version->parse($added_in) > $self->starting_version;

            my $has = $Module::CoreList::version{$self->starting_version}{$prereq};
            $has = version->parse($has);    # XXX bug? cannot do this in one line, above
            my $wanted = version->parse($prereqs->{$phase}{requires}{$prereq});

            if ($has < $wanted)
            {
                $self->log_fatal('detected a ' . $phase . ' requires dependency on '
                    . $prereq . ' ' . $wanted . ': perl ' . $self->starting_version
                    . ' only has ' . $has);
            }

            if (not $self->deprecated_ok)
            {
                my $deprecated_in = Module::CoreList->deprecated_in($prereq);
                $self->log_fatal('detected a ' . $phase
                    . ' requires dependency that was deprecated from core in '
                    . $deprecated_in . ': '. $prereq)
                        if $deprecated_in;
            }
        }
    }
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
you have any declared prerequisites that are not shipped with perl.

You can specify the first perl version to check against, and which
prerequisite phase(s) are significant.

=for Pod::Coverage after_build mvp_aliases mvp_multivalue_args

=head1 OPTIONS

=over 4

=item * C<phase>

Indicates a phase to check against. Can be provided more than once; defaults
to C<runtime> and C<test>.  (See L<Dist::Zilla::Plugin::Prereqs> for more
information about phases.)

=item * C<starting_version>

Indicates the first perl version that should be checked against; any versions
earlier than this are not considered significant for the purposes of core
checks.  Defaults to C<5.005>.

=item * C<deprecated_ok>

A boolean flag indicating whether it is considered acceptable to depend on a
deprecated module. Defaults to 0.

=back

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-OnlyCorePrereqs>
(or L<bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=cut
