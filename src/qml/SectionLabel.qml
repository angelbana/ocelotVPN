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

// The quiet capital heading above a group. Letter-spaced, because capitals set
// solid at this size are hard to read.
RowLayout {
    id: root

    property string text: ""
    property string trailing: ""

    spacing: 8

    Text {
        text: root.text.toUpperCase()
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
        font.letterSpacing: 0.7
    }

    Item {
        Layout.fillWidth: true
    }

    Text {
        visible: root.trailing.length > 0
        text: root.trailing
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
        elide: Text.ElideRight
        Layout.maximumWidth: Math.round(200 * Theme.scale)
    }
}
