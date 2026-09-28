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

import QtQuick
import QtQuick.Controls.Basic

// The menu that opens on a right click. Written out here because the one the
// toolkit draws by default belongs to no design at all: a black rectangle with
// square corners in the middle of a window made of soft cards.
Menu {
    id: control

    implicitWidth: Math.round(190 * Theme.scale)
    padding: Math.round(5 * Theme.scale)
    margins: Math.round(6 * Theme.scale)

    background: Rectangle {
        radius: Theme.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.line
    }
}
