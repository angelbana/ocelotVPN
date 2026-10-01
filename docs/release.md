# Making a release

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](release.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](release.ru.md)

A release is made by
[.github/workflows/release.yml](../.github/workflows/release.yml). Push a tag
of the form `vX.Y.Z` and the run builds the Windows installer, the portable
archive it is assembled from, and the Linux app image; signs the installer and
the program inside it; and attaches all three to the release page together with
their checksums.

## Version scheme

Work happens on `main`, or on `feature/*` branches. The version string is
generated at build time from git:

    <major>.<minor>.<patch>[-rev_count-sha1][-dirty]

So only a build made from a tag carries a clean version; anything else says
which commit it came from, and a tree with uncommitted changes says `dirty`.

## The steps

Everything has to be committed first - an uncommitted tree marks the version
and the file names.

 1. Review what is going out in `CHANGELOG.md` and write the entry for the
    release.
 2. Set the version in `CMakeLists.txt` to the one being released. The
    program compares this number against the latest release on GitHub to tell
    whether a newer one exists, so a build that is ahead of the release has to
    say so.
 3. Commit both.
 4. Tag and push:

        git tag -a v1.0.0 -m "Ocelot 1.0.0"
        git push origin v1.0.0

The run then does the rest. Signing happens only for tag runs: the token is
held in the repository's secrets, and a branch build is left unsigned on
purpose.

## Signing

Only the x86-64 build is signed. There is no 32-bit build, and if one ever
appears it stays unsigned.

## After the release: winget

The manifests that let anyone install the program with

    winget install SculkDev.Ocelot

live in [contrib/winget](../contrib/winget). They are not read from here by
anything - Microsoft's own repository holds the copy winget uses - so each
release updates these three files and then sends them on:

 1. set `PackageVersion` in all three files to the version going out;
 2. in the installer manifest, point `InstallerUrl` at the new file and put the
    new `InstallerSha256` beside it (the release page carries a `.sha512` for
    people; winget wants SHA-256, which `sha256sum` prints);
 3. set `ReleaseDate` and `ReleaseNotesUrl`;
 4. submit them, either as a pull request to `microsoft/winget-pkgs` under
    `manifests/s/SculkDev/Ocelot/<version>/`, or with `wingetcreate update
    SculkDev.Ocelot --version <version> --urls <installer url>`.

A submission is reviewed by Microsoft's own automation before it appears, and
the installer has to stay downloadable at that address for as long as the
version is listed.

## When a push breaks the build

[.github/workflows/check.yml](../.github/workflows/check.yml) builds every push
and pull request on Linux and does nothing else - no packaging, no signing, no
Windows runner. It is there so that a mistake is found in the minute after it is
made rather than in the middle of a release, and it is kept to Linux because a
Windows runner minute costs twice as much.
