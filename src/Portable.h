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

// The two ways the same program can live on a computer.
//
// Unpacked into a folder that can be written to - a memory stick, a downloads
// folder - Ocelot keeps its settings and its log in a "data" folder beside
// itself and leaves nothing anywhere else. Sitting where an installer puts
// programs, it behaves like any other installed program: the settings go where
// the system keeps settings, and the folder it runs from is left alone.
//
// Which of the two it is, is decided from where the program is: a copy under
// Program Files is installed, anything else that can be written to is
// portable. Being able to write there is not enough on its own, because the
// program asks for administrator rights at every start and could write to
// Program Files as well.
//
// None of this applies away from Windows. The Linux build is an AppImage - one
// file that already goes wherever it is put - and installing it is the
// distribution's business rather than the program's.
namespace Portable {

// Decides which of the two this copy is, and points the settings at the folder
// beside the program when it is the portable one. Called once, before anything
// reads a setting.
void prepare();

// Whether this copy keeps everything beside itself.
bool isActive();

// The folder a portable copy keeps its settings and its log in; empty for an
// installed one.
QString dataDirectory();

// Whether installing is something this build can do at all.
bool canInstall();

// Where a copy would be installed to.
QString installDirectory();

// Whether this copy is the one that was installed by the button below, and so
// the one the entry in Programs and Features points at.
bool isInstalledCopy();

// Copies this program into installDirectory(), writes the Start menu shortcut
// and the entry in Programs and Features, and carries the settings across. The
// copy this is run from is left exactly as it was.
bool install(QString& error);

// The program that install() put there.
QString installedProgram();

// Starts the installed copy once this one has quit. Needed because the two are
// the same program as far as "one Ocelot at a time" is concerned: started while
// this one is still running, the new copy would only raise this window.
bool launchInstalledAfterExit(QString& error);

// Takes out everything install() put in. The folder itself is deleted last, by
// someone else: a program cannot remove the file it is running from.
bool uninstall(QString& error);

// The two command line flags: the one the entry in Programs and Features uses,
// and the one that installs without opening a window, for anyone who would
// rather type it or put it in a script.
const char* uninstallFlag();
const char* installFlag();

}
