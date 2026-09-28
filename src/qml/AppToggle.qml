/*
 * Copyright (C) 2014 Red Hat
 *
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
import QtQuick.Layouts

RowLayout {
    id: root

    property alias text: label.text
    property alias description: description.text
    property alias checked: toggle.checked

    signal switched(bool checked)

    spacing: 16

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            id: label
            Layout.fillWidth: true
            color: Theme.ink
            font.pixelSize: Theme.fontNormal
            wrapMode: Text.WordWrap
        }

        Text {
            id: description
            Layout.fillWidth: true
            color: Theme.muted
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }
    }

    Switch {
        id: toggle

        implicitWidth: Math.round(36 * Theme.scale)
        implicitHeight: Math.round(20 * Theme.scale)
        padding: 0

        indicator: Rectangle {
            width: Math.round(36 * Theme.scale)
            height: Math.round(20 * Theme.scale)
            radius: height / 2
            color: toggle.checked ? Theme.accent : Theme.lineStrong

            Rectangle {
                width: Math.round(16 * Theme.scale)
                height: Math.round(16 * Theme.scale)
                radius: width / 2
                y: Math.round(2 * Theme.scale)
                x: toggle.checked ? parent.width - width - Math.round(2 * Theme.scale) : Math.round(2 * Theme.scale)
                color: Theme.night ? "#f3f6fb" : "#ffffff"

                Behavior on x {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        onToggled: root.switched(checked)
    }
}
