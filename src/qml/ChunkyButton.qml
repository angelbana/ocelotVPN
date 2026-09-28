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

// The one big action on a screen. Filled with the colour of whatever it is
// about to do, and lifted a little under the pointer so it reads as pressable.
Button {
    id: root

    property color tint: Theme.accent
    property string glyph: ""
    property bool busy: false

    implicitHeight: Math.round(38 * Theme.scale)
    implicitWidth: Math.max(Math.round(150 * Theme.scale),
        contentRow.implicitWidth + Math.round(34 * Theme.scale))
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: Theme.radius
        color: root.down ? Qt.darker(root.tint, 1.1)
            : root.hovered ? root.tint
            : Qt.alpha(root.tint, 0.94)
        border.width: 1
        border.color: Qt.alpha("#ffffff", Theme.night ? 0.12 : 0.24)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 2
            border.color: Qt.alpha(root.tint, 0.45)
            visible: root.visualFocus
        }

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: 7

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph.length > 0 && !root.busy
                name: root.glyph
                color: Theme.night && root.tint === Theme.accent ? Theme.accentInk : "#ffffff"
                size: Math.round(15 * Theme.scale)
                thickness: 2.1
            }

            // A ring that turns while the program waits, rather than a control
            // that looks frozen.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.busy
                width: Math.round(15 * Theme.scale)
                height: width

                Rectangle {
                    id: spinner

                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, Math.round(1.8 * Theme.scale))
                    border.color: Qt.alpha("#ffffff", 0.35)

                    Rectangle {
                        width: parent.border.width
                        height: parent.border.width
                        radius: width / 2
                        color: "#ffffff"
                        x: parent.width / 2 - width / 2
                        y: -width / 2
                    }

                    RotationAnimation on rotation {
                        running: root.busy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: Theme.night && root.tint === Theme.accent ? Theme.accentInk : "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.weight: Font.DemiBold
            }
        }
    }
}
