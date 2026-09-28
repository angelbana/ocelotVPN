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

// One line of a menu, in the same colours as everything else.
MenuItem {
    id: control

    implicitHeight: Math.round(30 * Theme.scale)
    leftPadding: Math.round(10 * Theme.scale)
    rightPadding: Math.round(10 * Theme.scale)

    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.highlighted && control.enabled ? Theme.cardHover : "transparent"
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? Theme.ink : Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontNormal
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
