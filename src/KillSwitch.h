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

// Keeping traffic from going anywhere but the tunnel.
//
// A tunnel that drops does not take the applications with it: they carry on
// over the ordinary connection, and whatever they were sending through the VPN
// goes out in the open instead. This shuts that door - while the tunnel is up
// nothing else gets out, and when it falls over, nothing gets out at all until
// the person says so.
//
// Four things are let through, and nothing else: whatever leaves through the
// tunnel itself, this program's own sockets (otherwise it could not reach the
// server to reconnect), the loopback, and DHCP, so the computer keeps its
// address on the network it is sitting on.
//
// The rules are put in a session the system itself tears down when this program
// goes away - a crash, a kill, the machine losing power. That is deliberate: a
// computer whose network was shut by a program that no longer exists would be a
// far worse bug than a leak.
//
// Windows only. The filtering platform this is built on has no equivalent here
// that could be relied upon; on Linux it would be the firewall's business.
namespace KillSwitch {

// Whether this system can do it at all.
bool isSupported();

// Whether the rules are in place right now.
bool engaged();

// Shuts everything but the tunnel the given address belongs to. Returns false
// and fills in error when the rules could not be written; nothing is left half
// done in that case.
bool engage(const QString& tunnelAddress, QString& error);

// Lets everything through again.
void release();

}
