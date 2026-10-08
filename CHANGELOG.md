History of user-visible changes.

Ocelot grew out of openconnect-gui. That project's own history stays with it
upstream; this file begins with the first Ocelot release.

## 1.1.1 - 2026-10-08

- Manual update checks always ask GitHub again instead of reusing the version
  found earlier in the same application session.
- Uses the system window frame by default for new settings, while keeping
  an existing frame selection.
- Explicitly restores the system title bar and window buttons when switching
  away from the Ocelot frame, and reapplies decorations without losing the
  window's current state.

## 1.1.0 - 2026-10-07

- **Keeps remembered passwords when sign-in is cancelled.** Cancelling a
  one-time code no longer clears the account password or starts another
  sign-in attempt. Passwords are saved before the next question, and codes
  are kept out of the profile. Windows password decoding and write-failure
  handling have also been corrected.
- **Keeps reconnecting after a dropped session.** Automatic reconnection
  continues with increasing delays until the server is available again;
  cancelling sign-in or rejected credentials stops the retries.
- **Blocks traffic outside the tunnel on Windows**, when the optional kill
  switch is enabled, including while reconnecting after a dropped connection.
- **Supports sign-in through a browser** when the VPN server asks for it.
- **Downloads and installs updates** from the application's settings.
- **Shares profiles without passwords** and can forget all saved passwords.
- Fixes profile DNS-setting loading, server-form selection and Windows
  installer packaging with newer MSYS2 NSIS packages.

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
