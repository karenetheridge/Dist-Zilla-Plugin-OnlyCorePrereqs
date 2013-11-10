# NAME

Dist::Zilla::Plugin::OnlyCorePrereqs - Check that no prerequisites are declared that are not part of core

# VERSION

version 0.009

# SYNOPSIS

In your `dist.ini`:

    [OnlyCorePrereqs]
    starting_version = 5.010

# DESCRIPTION

`[OnlyCorePrereqs]` is a [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) plugin that checks at build time if
you have any declared prerequisites that are not shipped with Perl.

You can specify the first Perl version to check against, and which
prerequisite phase(s) are significant.

If the check fails, the build is aborted.

# OPTIONS

- `phase`

    Indicates a phase to check against. Can be provided more than once; defaults
    to `runtime` and `test`.  (See [Dist::Zilla::Plugin::Prereqs](http://search.cpan.org/perldoc?Dist::Zilla::Plugin::Prereqs) for more
    information about phases.)

    Remember that you can use different settings for different phases by employing
    this plugin twice, with different names.

- `starting_version`

    Indicates the first Perl version that should be checked against; any versions
    earlier than this are not considered significant for the purposes of core
    checks.  Defaults to `5.005`.

    There are two special values supported:

    - `current` - indicates the version of Perl that you are currently running with
    - `latest` - indicates the most recent (stable or development) release of Perl

    (Note: if you wish to check against __all__ changes in core up to the very
    latest Perl release, you should upgrade your [Module::CoreList](http://search.cpan.org/perldoc?Module::CoreList) installation.
    You can guarantee you are always running the latest version with
    [Dist::Zilla::Plugin::PromptIfStale](http://search.cpan.org/perldoc?Dist::Zilla::Plugin::PromptIfStale). [Module::CoreList](http://search.cpan.org/perldoc?Module::CoreList) is also the mechanism used for
    determining the version of the latest Perl release.)

- `deprecated_ok`

    A boolean flag indicating whether it is considered acceptable to depend on a
    deprecated module. Defaults to 0.

- `check_dual_life_versions`

    A boolean flag indicating whether the specific module version available in the
    `starting_version` of perl be checked (even) if the module is dual-lifed.
    Defaults to 1.

    This is useful to __unset__ if you don't want to fail if you require a core module
    that the user can still upgrade via the CPAN, but do want to fail if the
    module is __only__ available in core.

    Note that at the moment, the "is this module dual-lifed?" heuristic is not
    100% reliable, as we may need to interrogate the PAUSE index to see if the
    module is available outside of perl -- which can generate a false negative if
    the module is upstream-blead and there was a recent release of a stable perl.
    This is hopefully going to be rectified soon (when I add the necessary feature
    to [Module::CoreList](http://search.cpan.org/perldoc?Module::CoreList)).

    (For example, a prerequisite of [Test::More](http://search.cpan.org/perldoc?Test::More) 0.88 at `starting_version`
    5.010 would fail with `check_dual_life_versions = 1`, as the version of
    [Test::More](http://search.cpan.org/perldoc?Test::More) that shipped with that version of perl was only 0.72,
    but not fail if `check_dual_life_versions = 0`.

# SUPPORT

Bugs may be submitted through [the RT bug tracker](https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-OnlyCorePrereqs)
(or [bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org](mailto:bug-Dist-Zilla-Plugin-OnlyCorePrereqs@rt.cpan.org)).
I am also usually active on irc, as 'ether' at `irc.perl.org`.

# AUTHOR

Karen Etheridge <ether@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

# CONTRIBUTOR

David Golden <dagolden@cpan.org>
