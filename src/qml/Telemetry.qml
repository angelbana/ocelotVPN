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

pragma Singleton

import QtQuick

// The recent history of the throughput, kept in one place.
//
// The window and the popover both draw it, and both can be closed and opened
// again; a chart that kept its own history would start empty every time one of
// them appeared. The samples are fed in by Main.qml, which is the one thing
// that is always there.
QtObject {
    readonly property int capacity: 60

    property var rx: []
    property var tx: []

    function push(rxRate, txRate) {
        // Reassigned rather than appended to: a property holding an array only
        // reports a change when the property itself is set.
        const nextRx = rx.slice(rx.length >= capacity ? 1 : 0);
        const nextTx = tx.slice(tx.length >= capacity ? 1 : 0);
        nextRx.push(Math.max(0, rxRate));
        nextTx.push(Math.max(0, txRate));
        rx = nextRx;
        tx = nextTx;
    }

    function clear() {
        rx = [];
        tx = [];
    }
}
