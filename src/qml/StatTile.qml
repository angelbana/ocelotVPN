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
import QtQuick.Layouts

// One labelled number, with its own colour and a line of detail underneath.
ColumnLayout {
    id: root

    property string glyph: ""
    property string label: ""
    property string value: ""
    property string detail: ""
    property color tint: Theme.accent

    spacing: 2

    RowLayout {
        spacing: 4

        Glyph {
            name: root.glyph
            color: root.tint
            size: Math.round(11 * Theme.scale)
            thickness: 2.2
        }

        Text {
            text: root.label.toUpperCase()
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }
    }

    Text {
        text: root.value
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontMedium
        font.weight: Font.DemiBold
        // Digits that line up, so a changing number does not shuffle the layout.
        font.features: { "tnum": 1 }
    }

    Text {
        Layout.fillWidth: true
        visible: root.detail.length > 0
        text: root.detail
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        elide: Text.ElideRight
    }
}
