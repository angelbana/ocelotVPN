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

// The small label that explains an icon with no words next to it. Declared
// inside the control it belongs to, rather than through the attached property,
// so that it can be drawn like the rest of the program.
ToolTip {
    id: control

    delay: 600
    padding: 0

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.night ? Theme.cardHover : Qt.rgba(0.17, 0.15, 0.13, 0.96)
        border.width: Theme.night ? 1 : 0
        border.color: Theme.lineStrong
    }

    contentItem: Text {
        leftPadding: Math.round(9 * Theme.scale)
        rightPadding: Math.round(9 * Theme.scale)
        topPadding: Math.round(5 * Theme.scale)
        bottomPadding: Math.round(5 * Theme.scale)
        text: control.text
        color: Theme.night ? Theme.ink : "#fdf8f1"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
    }
}
