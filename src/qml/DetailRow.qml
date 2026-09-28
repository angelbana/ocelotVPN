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

// A key on the left, its value on the right. The details list is made of these.
RowLayout {
    id: root

    property string label: ""
    property string value: ""
    property bool mono: false

    spacing: 10

    Text {
        text: root.label
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
    }

    Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 8
    }

    Text {
        Layout.maximumWidth: Math.round(320 * Theme.scale)
        text: root.value.length > 0 ? root.value : "—"
        color: root.value.length > 0 ? Theme.ink : Theme.faint
        font.family: root.mono && root.value.length > 0 ? Theme.monoFamily : Theme.fontFamily
        font.pixelSize: root.mono ? Theme.fontSmall : Theme.fontCaption
        font.weight: root.mono ? Font.Normal : Font.Medium
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }
}
