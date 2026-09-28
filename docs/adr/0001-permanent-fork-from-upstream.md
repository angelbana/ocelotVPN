# 1. A permanent fork, not a tracking one

## Status

Accepted, 2026-09-13.

## Context

This code started as a copy of openconnect-gui from
https://gitlab.com/openconnect/openconnect-gui and has since diverged far
enough that the two are no longer the same program in any practical sense: the
interface was rewritten from Qt Widgets to QML, the program became Ocelot and
was re-iconed, macOS support was dropped in favour of a separate client, and
the build gained a release workflow of its own that signs the Windows build
through a hardware token.

Upstream keeps developing the Widgets interface. Merging its changes would mean
resolving conflicts in files that no longer exist here, and would only grow
harder with every release.

## Decision

Treat the divergence as permanent. Nothing is merged from upstream. Fixes that
matter are read, understood and reimplemented here by hand, one at a time.

The same reasoning is applied to the vpnc script: its modified version lives in
this repository rather than being patched onto a clone of the upstream one at
build time.

## Consequences

Upstream security fixes do not arrive on their own. Someone has to watch the
upstream project and decide, per fix, whether it applies here - and nothing in
the build will remind them.

In exchange, the tree is ours: changes are made where the code lives, without
arranging them to survive a future merge, and a reader is never left wondering
which half of a file came from where.

The openconnect *library* is a separate matter and is not covered by this
decision: it is consumed as a dependency at a pinned version, not forked.
