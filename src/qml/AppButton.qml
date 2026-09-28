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

Button {
    id: control

    // normal | primary | danger | solidDanger | flat
    property string kind: "normal"
    property bool compact: false

    readonly property bool filled: kind === "primary" || kind === "solidDanger"
    readonly property color fillColor: kind === "primary" ? Theme.accent
        : kind === "solidDanger" ? Theme.danger
        : Theme.surface
    readonly property color textColor: kind === "primary" ? Theme.accentInk
        : kind === "solidDanger" ? Theme.dangerInk
        : kind === "danger" ? Theme.danger
        : kind === "flat" ? Theme.accent
        : Theme.ink

    implicitHeight: compact ? Theme.controlHeightSmall : Theme.controlHeight
    leftPadding: Math.round((compact ? 10 : 16) * Theme.scale)
    rightPadding: Math.round((compact ? 10 : 16) * Theme.scale)
    font.pixelSize: compact ? Theme.fontSmall : Theme.fontNormal
    font.weight: Font.DemiBold
    opacity: enabled ? 1.0 : 0.5

    background: Rectangle {
        radius: Theme.radius
        color: control.kind === "flat" ? "transparent"
            : control.hovered && !control.filled ? Theme.sunken
            : control.fillColor
        border.width: control.filled || control.kind === "flat" ? 0 : 1
        border.color: Theme.lineStrong
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
