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

    gh run download <run-id> -R angelbana/ocelotVPN -n windows-installer

| Artifact            | Contents                                        | Signed |
|---------------------|-------------------------------------------------|--------|
| `windows-installer` | an installer and its SHA-512 checksum           | yes    |
| `windows-portable`  | a folder to unpack anywhere, and its checksum   | yes    |
| `linux-appimage`    | an app image and its SHA-512 checksum           | no     |

The program inside the portable archive is the same signed executable the
installer carries; the archive itself is not signed, which is why it has a
checksum.

Verify the checksum against the `.sha512` file next to each file if it was
passed around outside the workflow run.


## Windows

There are two ways to have it, and the program knows which one it is in.

### Installed

Download `windows-installer`, unpack the archive and run the installer. The
program goes to `C:\Program Files\Ocelot`, and the settings and the profiles
go where Windows keeps such things, under the current user.

The installer and the program inside it are both Authenticode-signed and
timestamped, so Windows names the publisher instead of warning about an
unknown one. To check before installing:

    Get-AuthenticodeSignature .\ocelot-<version>-win64.exe

### Carried around

Download `windows-portable` and unpack the `Ocelot` folder wherever it should
live: a memory stick, a downloads folder, a second drive. There is nothing to
install and nothing to agree to. Such a copy keeps its settings, its profiles
and its log in a `data` folder beside the program, and leaves nothing anywhere
else on the machine.

Which of the two it is, is decided from where the program sits. Under
`Program Files`, `ProgramData` or `%LOCALAPPDATA%\Programs` it behaves as an
installed program; anywhere else it can write to, it keeps everything beside
itself. Nothing has to be set, and no marker file has to be put in the folder.

**Installing a carried copy.** Settings, "This copy of Ocelot", Install: the
program copies itself to `C:\Program Files\Ocelot`, puts a shortcut in the
Start menu and an entry in Programs and Features, and carries the settings and
profiles across, so the installed copy opens on the same profiles. The folder it
was started from is left exactly as it was and can go back on the stick. The
same thing without a window:

    .\ocelot.exe --install

**Taking it back out.** In the installed copy: Settings, "This copy of Ocelot",
Remove. Or the entry in Programs and Features, which runs

    "C:\Program Files\Ocelot\ocelot.exe" --uninstall

Either way the program, the shortcut, the entry and the sign-in task go, and the
profiles and the passwords saved with them stay - installing again finds them
where they were.

A saved password is sealed by Windows for the account that saved it on the
computer that saved it. A folder carried to another machine therefore carries
the profiles, but not the passwords stored with them.

**Letting nothing out except through the tunnel.** Settings, Safety: with this
on, while the tunnel is up nothing else on the computer reaches the network, and
if the tunnel falls over nothing gets out at all until you disconnect - which is
the point, since a tunnel that drops does not take the programs using it with
it. Four things are still let through: the tunnel itself, Ocelot's own
connection to the server (otherwise it could not dial back), the computer
talking to itself, and the lease that keeps its address on the network it is
plugged into.

The rules live in a session Windows itself tears down when Ocelot goes away, so
a crash cannot leave a computer that will not talk to anything. Another VPN
running beside Ocelot stops working while this is on - that is not a fault, it
is what "nothing outside the tunnel" means.

**Signing in through a browser.** Where a server does not ask for a password at
all but hands the sign-in to a browser - a company login page, a smart card, a
phone - Ocelot opens that page in the browser already on the computer, says so,
and waits. Nothing else is needed: once the sign-in is done there, the
connection carries on by itself. This needs openconnect 9.0 or newer, which both
published builds carry.

**Updating.** Settings, Maintenance, Updates: the program asks GitHub what the
latest release is, and where it can replace itself it offers to. What it
downloads is the installer for an installed copy and the archive for a carried
one. Before anything is run, the file is measured against the SHA-512 published
beside it, and an installer that carries no signature Windows accepts is deleted
rather than started - the name it is signed with is shown before you agree. A
carried copy is replaced in place, keeping its `data` folder, and started again.

The program requires administrator privileges and asks for them on every
start: creating the Wintun adapter is impossible without them, and the
connection is dropped right after the tunnel is negotiated if they are
missing. This is the intended behaviour, not a prompt to dismiss.

Everything the program needs is beside it either way: the Qt runtime, the
openconnect libraries, `wintun.dll` and `vpnc-script.js`. Nothing is looked for
in a system folder, which is what lets the same files work from a stick.


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
