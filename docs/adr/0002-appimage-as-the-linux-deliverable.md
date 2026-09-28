# 2. One app image for Linux, not a package per distribution

## Status

Accepted, 2026-09-13.

## Context

The Linux build used to be published as a bare executable compiled on Fedora 41.
Running it elsewhere was tried:

- Fedora 41 - runs.
- Debian 13 - runs, but only after installing the QML modules Debian splits out
  of qtdeclarative; without `qml6-module-qtquick-layouts` the program starts and
  then dies with `module "QtQuick.Layouts" is not installed`, which reads like a
  broken build rather than a missing package.
- Ubuntu 24.04 - cannot run it at all. It ships Qt 6.4.2 while the program needs
  symbols from 6.8 and a library that did not exist yet:
  `libQt6Core.so.6: version 'Qt_6.8' not found`, `libQt6QmlMeta.so.6 => not found`.

The root cause is not packaging but the toolkit: distributions ship different
Qt versions, and the program needs 6.5 or newer for the system theme it follows.
A package per distribution would mean building against each one's Qt - and for
Ubuntu 24.04, dropping the feature that needs 6.5.

## Decision

Publish one app image for Linux, built on Ubuntu 22.04 so the glibc floor stays
low, carrying Qt 6.8, openconnect 9.12 built from source, and the vpnc script.
No distribution packages.

## Consequences

One artifact to build and to test, and the same behaviour everywhere, including
the same openconnect version the Windows build uses - the distribution only has
to be no older than Ubuntu 22.04.

The file is large, because the toolkit travels with it. It does not integrate
with the system the way a package would: no menu entry unless the person adds
one. It has to be started with `sudo`, since the program creates a tun device and
does not ask for privileges itself.

Building openconnect from source makes the Linux job noticeably longer than
installing a package would have.
