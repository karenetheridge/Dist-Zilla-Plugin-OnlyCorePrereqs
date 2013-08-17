# NAME

Dist::Zilla::Plugin::OnlyCorePrereqs - Check that no prerequisites are declared that are not part of core

# VERSION

version 0.002

# SYNOPSIS

In your `dist.ini`:

    [OnlyCorePrereqs]
    starting_version = 5.010

# DESCRIPTION

`[OnlyCorePrereqs]` is a [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) plugin that checks at build time if
you have any declared prerequisites that are not shipped with perl.

You can specify the first perl version to check against, and which
prerequisite phase(s) are significant.

# OPTIONS

- `phase`

    Indicates a phase to check against. Can be provided more than once; defaults
    to `runtime` and `test`.  (See [Dist::Zilla::Plugin::Prereqs](http://search.cpan.org/perldoc?Dist::Zilla::Plugin::Prereqs) for more
    information about phases.)

- `starting_version`

    Indicates the first perl version that should be checked against; any versions
    earlier than this are not considered significant for the purposes of core
    checks.  Defaults to `5.005`.

- `deprecated_ok`

    A boolean flag indicating whether it is considered acceptable to depend on a
    deprecated module. Defaults to 0.

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
