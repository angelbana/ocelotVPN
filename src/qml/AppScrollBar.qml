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

// A scrollbar that stays out of the way: nothing at rest, a soft bar while the
// list is being moved.
ScrollBar {
    id: control

    implicitWidth: Math.round((orientation === Qt.Vertical ? 11 : 40) * Theme.scale)
    implicitHeight: Math.round((orientation === Qt.Vertical ? 40 : 11) * Theme.scale)
    x: orientation === Qt.Vertical && parent ? parent.width - width : 0
    y: orientation === Qt.Horizontal && parent ? parent.height - height : 0
    width: orientation === Qt.Horizontal && parent ? parent.width : implicitWidth
    height: orientation === Qt.Vertical && parent ? parent.height : implicitHeight
    visible: policy !== ScrollBar.AlwaysOff && (policy === ScrollBar.AlwaysOn || size < 1)
    padding: Math.round(3 * Theme.scale)

    background: Item {}

    contentItem: Rectangle {
        implicitWidth: Math.round((control.orientation === Qt.Vertical ? 5 : 40) * Theme.scale)
        implicitHeight: Math.round((control.orientation === Qt.Vertical ? 40 : 5) * Theme.scale)
        radius: width / 2
        color: control.pressed ? Theme.muted : Theme.lineStrong
        opacity: control.policy === ScrollBar.AlwaysOn || control.active ? 0.85 : 0

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }
    }
}
