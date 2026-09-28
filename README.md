# Ocelot for Windows

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](README.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](README.ru.md)

A VPN client for servers that speak the Cisco AnyConnect protocol, built on
OpenConnect. Windows is the system it is made for; a Linux app image is built
alongside it.

For macOS there is a client of its own:
[ocelotVPN](https://github.com/mraliscoder/ocelotVPN).

This program began as a fork of
[OpenConnect VPN GUI](https://gui.openconnect-vpn.net/) and has since been
rebuilt on Qt 6 and QML.


## What it is for

A simple, minimal way into a VPN. The people it is written for are not
expected to know what a tun device is, and nothing about the program asks them
to.

### One click away

 - connecting to a new server;
 - connecting to a saved server;
 - disconnecting;
 - reading the log.

### It remembers things so you do not have to

 - the password for a profile, kept by Windows itself rather than by us;
 - connecting on its own: when the program starts, when you sign in to
   Windows, and again after a connection drops;
 - starting on its own, as a scheduled task, so Windows does not ask for
   permission at every sign-in.

It also lives in the notification area: one click opens a small window with the
state, one button and the profiles, which is all an ordinary day needs.

### Three themes, two languages

Night, day and ocelot: they change the colours and nothing else, the layout is
the same in all three. The interface speaks English and Russian, follows
Windows by default, and switches without a restart.

### Security

Because the audience is not technical, security decisions are not handed to
the user unless there is no other way.

#### Checking the server's certificate

The SSL VPN servers openconnect works with have historically had certificates
with the wrong host name in them, and certificates outside the public key
infrastructure of the internet. So the program:

 1. tries ordinary public key infrastructure validation - if that succeeds,
    the server is confirmed;
 2. otherwise falls back to SSH-style checking, where the server's public key
    must stay the same as last time.


## What you get

| System               | Deliverable                                      | Signed |
|----------------------|--------------------------------------------------|--------|
| Windows 10 and newer | an installer                                     | yes    |
| Linux, x86-64        | an app image: one file carrying Qt with it       | no     |

The Windows installer and the program inside it are both Authenticode-signed
and timestamped, so Windows names the publisher rather than warning about an
unknown one.

The Linux app image has been started on Ubuntu 24.04, a system older than the
one it is built on and one that cannot run a bare build at all - carrying Qt
along is what the app image is for.

See [Running the published builds](docs/running.md) for what each one needs
from the system.


## Running the program
- [Running the published builds](docs/running.md) - what each build artifact
  contains, what the Windows installer brings with it, and what a Linux system
  has to provide on its own

## Development info
- [Building from source](docs/dev.md) - Windows and Linux
- [Development with QtCreator](docs/dev_QtCreator.md)
- [Making a release](docs/release.md)
- [The words this project uses](CONTEXT.md)

# License
The content of this project itself is licensed under the [GNU General Public License v2](LICENSE.txt)
