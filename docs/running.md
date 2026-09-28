# Running the program

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](running.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](running.ru.md)

Ocelot is built for Windows and for Linux, and each one is published as an
artifact of the release workflow run. Both deliverables carry what they need
with them, except for the system libraries named below.

For macOS there is a client of its own:
[ocelotVPN](https://github.com/mraliscoder/ocelotVPN). This project does not
build one.

Artifacts of a run are listed at the bottom of its page under
`Actions -> Release -> <run>`, or with the GitHub CLI:

    gh run download <run-id> -R angelbana/ocelotVPN-windows -n windows-installer

| Artifact            | Contents                                        | Signed |
|---------------------|-------------------------------------------------|--------|
| `windows-installer` | an installer and its SHA-512 checksum           | yes    |
| `linux-appimage`    | an app image and its SHA-512 checksum           | no     |

Verify the checksum against the `.sha512` file next to each file if it was
passed around outside the workflow run.


## Windows

Download `windows-installer`, unpack the archive and run the installer.

The installer and the program inside it are both Authenticode-signed and
timestamped, so Windows names the publisher instead of warning about an
unknown one. To check before installing:

    Get-AuthenticodeSignature .\ocelot-<version>-win64.exe

The program requires administrator privileges and asks for them on every
start: creating the Wintun adapter is impossible without them, and the
connection is dropped right after the tunnel is negotiated if they are
missing. This is the intended behaviour, not a prompt to dismiss.

Everything the program needs is installed with it: the Qt runtime, the
openconnect libraries, `wintun.dll` and `vpnc-script.js`.


## Linux

Download `linux-appimage`, make it executable and run it:

    chmod +x ocelot-x86_64.AppImage
    sudo ./ocelot-x86_64.AppImage

Root privileges are needed for the tun device; the program does not elevate
itself, so it has to be started with them.

The app image carries Qt, its QML modules, the openconnect library and GnuTLS
inside it, so no packages have to be installed for them. What it expects from
the distribution is the graphics and font stack that every desktop already
has - these are deliberately not bundled, because they are tied to the
machine's own drivers:

    libGLX.so.0  libOpenGL.so.0  libEGL.so.1  libX11.so.6
    libfontconfig.so.1  libfreetype.so.6  libharfbuzz.so.0

It also needs `/etc/vpnc/vpnc-script`, which comes with the `vpnc-scripts`
package in most distributions.

GNOME has no notification area of its own, so the icon and the popover that
belongs to it do not appear there unless an extension provides one. The program
says so in its log and carries on; everything is in the window.

### Where it has been run

The app image was started on **Ubuntu 24.04** and kept running. That is the
point of it: Ubuntu 24.04 ships Qt 6.4, while the program is built against a
newer Qt on Fedora, and a bare build of it cannot start there at all -

    libQt6Core.so.6: version `Qt_6.8' not found

The app image has no such problem, since the Qt it was built against travels
with it.

Connecting has not been exercised that way, since it wants root and a tun
device, so treat the first real connection as a test.


## Where the version comes from

The version in the file name is produced by `git describe --tags`, so it
follows the tag the run was started from. The name is not the tag verbatim:
the leading `v` is dropped and the hyphen becomes a dot, so the tag `v1.0.0`
produces `ocelot-1.0.0-oc-9.12-win64.exe`.

A run started from a branch rather than a tag carries the commit description
instead, and a tree that git considers modified adds a `dirty` suffix.
