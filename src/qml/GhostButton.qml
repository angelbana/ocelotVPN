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

// The quiet button: an icon, sometimes a word, and no fill until the pointer is
// over it. Everything that is not the main action on a screen is one of these.
Button {
    id: root

    property color tint: Theme.muted
    property string glyph: ""
    property bool selected: false

    implicitHeight: Math.round(text.length > 0 ? 26 * Theme.scale : 24 * Theme.scale)
    implicitWidth: row.implicitWidth + Math.round((text.length > 0 ? 18 : 12) * Theme.scale)
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        radius: Theme.radiusSmall
        color: root.selected ? Theme.accentSoft
            : root.down ? Theme.cardHover
            : root.hovered ? Theme.cardHover
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 5

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph.length > 0
                name: root.glyph
                color: root.selected ? Theme.accent : root.hovered ? Theme.ink : root.tint
                size: Math.round(13 * Theme.scale)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text.length > 0
                text: root.text
                color: root.selected ? Theme.accent : root.hovered ? Theme.ink : root.tint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Medium
            }
        }
    }

    ToolTip.visible: hovered && ToolTip.text.length > 0
    ToolTip.delay: 600
}
