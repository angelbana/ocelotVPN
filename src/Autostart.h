/*
 * This file is part of Ocelot.
 *
 * Ocelot is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

#include <QString>

// Starting Ocelot when the user signs in.
//
// The usual startup folder or Run key cannot be used: the program asks for
// administrator privileges, and Windows answers a privileged program in a
// startup entry with a consent dialog at every sign-in, or refuses to start it
// at all. A scheduled task registered to run with the highest privileges is the
// one way in: it starts elevated without asking, because the permission was
// given once when the task was created.
//
// Nothing else on Linux needs this - a program that has to be started with
// root cannot usefully start itself at login - so there it is unsupported and
// the setting is not offered.
namespace Autostart {

// Whether this system has a way to do it at all.
bool isSupported();

// Whether the task exists right now. Asked of the system rather than
// remembered, so the answer stays true after someone deletes the task by hand.
bool isEnabled();

// Creates or deletes the task. Returns false and fills in error when the
// system refused; the caller is expected to show that text.
bool setEnabled(bool enabled, QString& error);

// The command line flag the task passes, so the program can tell a start at
// sign-in from a start by hand.
const char* logonFlag();

}
