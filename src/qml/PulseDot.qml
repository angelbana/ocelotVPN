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

// The breathing dot that says something is happening, and a still one when
// nothing is: a ring that never stops expanding stops meaning anything.
Item {
    id: root

    property color tint: Theme.ok
    property bool active: false
    property int dotSize: Math.round(8 * Theme.scale)

    implicitWidth: dotSize
    implicitHeight: dotSize

    Rectangle {
        id: ring

        anchors.centerIn: parent
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, Math.round(1.5 * Theme.scale))
        border.color: root.tint
        visible: root.active
        opacity: 0
        scale: 1

        ParallelAnimation {
            running: root.active
            loops: Animation.Infinite

            NumberAnimation {
                target: ring
                property: "scale"
                from: 1
                to: 2.5
                duration: 1400
                easing.type: Easing.OutQuad
            }
            SequentialAnimation {
                NumberAnimation {
                    target: ring
                    property: "opacity"
                    from: 0
                    to: 0.75
                    duration: 80
                }
                NumberAnimation {
                    target: ring
                    property: "opacity"
                    to: 0
                    duration: 1320
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: root.tint
    }
}
