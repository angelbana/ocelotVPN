History of user-visible changes.

Ocelot grew out of openconnect-gui. That project's own history stays with it
upstream; this file begins with the first Ocelot release.

## 1.0.0 - 2026-09-30

The first Ocelot release. What it does that openconnect-gui did not:

- **Remembers a password.** The old switch never worked: nothing ever handed
  the password to the profile, so it asked at every connection. Windows seals a
  remembered password to the account it was saved from, and turning the switch
  off deletes it.
- **Connects without being asked**, in three separate ways: when the program
  starts, when you sign in to Windows, and again after a connection drops.
- **Starts with Windows** as a scheduled task - the only way a program that
  needs administrator rights can start at sign-in without asking every time.
- **A window from the notification area.** One click gives the state, one
  button and the profiles; the main window is for setting things up.
- **Three themes** - night, day and ocelot - that change colour and nothing
  else.
- **Two languages.** English and Russian, following Windows unless told
  otherwise, switched without a restart.
- **A profile has a character**, can be duplicated, and says when it last
  connected.
- **Name resolution per profile**: the domains the server asks for, or every
  name through the tunnel.
- **Says when a tunnel comes up or goes down**, and looks for new versions -
  both switchable.
- **Runs from a folder, or installs itself.** Unpacked anywhere it can write,
  it keeps its settings, profiles and log beside it and touches nothing else; a
  button in the settings installs it into Program Files, with a shortcut and an
  entry in Programs and Features, and carries the profiles across. The same
  place in an installed copy removes it. Published as a portable archive next to
  the installer.

macOS is no longer built here; that client is its own project,
[ocelotVPN](https://github.com/mraliscoder/ocelotVPN).
