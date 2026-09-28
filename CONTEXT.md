# Context

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](CONTEXT.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](CONTEXT.ru.md)

The vocabulary this project uses. Terms here mean exactly what is written; if
code or a document uses one of them differently, that is a defect in the code or
the document.

## Build

The result of one CI job for one operating system. There is a Windows build and
a Linux build. A build is not something a person receives.

## Artifact

A file attached to a workflow run. Artifacts expire and disappear with the run,
so an artifact is never the answer to "where do I download it".

## Release

A tag, the page that belongs to it, and the files attached to that page. A
release is permanent and is what a person is given a link to.

## Installer

The Windows file that installs the program. Only Windows has one: the Linux app
image is not an installer and is not called that.

## App image

The single Linux file that carries the program and everything it needs to run,
including the toolkit itself. It depends on the distribution only for the
oldest system libraries.

## Profile

A server configuration saved in the program - its address, protocol,
credentials, certificates and its icon. A profile is what the person picks
before connecting; it is not a connection and it is not a session.

## Profile icon

The emoji a person chooses for a profile, so one is told from another at a
glance. It is chosen from a fixed set; it is not fetched from the server and it
is not a file on disk.

## Theme

A set of colours, switched in the settings. There are three - night, day and
ocelot - and they change nothing but colour: the window is laid out the same
way under all of them. A theme is not a skin and not a second interface.

## Mascot

The drawn character that carries the program's identity and changes with the
state of the connection.

## Auto-connect

Connecting without being asked. Three separate things, each switched on its
own: when the program starts, when the person signs in to Windows, and after a
connection drops. The profile used at sign-in is one named in the settings, not
whichever was used last.

## Autostart

Starting the program when the person signs in to Windows. It is a scheduled
task rather than an entry in the startup list, because the program needs
administrator rights and a startup entry would ask for them every time.

## Split DNS

The set of domains the server asks the client to resolve through the tunnel,
leaving everything else to the resolvers the machine already had. The server
states this, and the client obeys it; the client never decides the set itself.

Distinct from sending *all* DNS through the tunnel, which a profile can ask for
whatever the server said. That choice is the profile's *name resolution*
setting, and it is the only DNS decision this program makes on its own.

## Popover

The small window that one click on the notification area icon opens: the state,
the one button, and the profiles. It is not the main window shrunk, and not a
menu - it is where the program is used on an ordinary day.

## Language

The language the interface speaks: English, Russian, or whichever of the two
Windows is set to. It changes while the program runs and is not a restart.
Nothing in a profile, a log line or a server's own message is translated - only
the program's own words.

## Duplicate

A copy of a profile under a new name, certificates, pinned key and saved
password included. A duplicate has never connected, so it starts with no
last-connected time of its own.
