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

TextField {
    id: control

    property bool mono: false

    implicitHeight: Theme.controlHeight
    leftPadding: Math.round(10 * Theme.scale)
    rightPadding: Math.round(10 * Theme.scale)
    color: Theme.ink
    placeholderTextColor: Theme.faint
    selectByMouse: true
    font.pixelSize: mono ? Theme.fontSmall : Theme.fontNormal
    font.family: mono ? Theme.monoFamily : Application.font.family

    background: Rectangle {
        radius: Theme.radius
        color: control.enabled ? Theme.surface : Theme.sunken
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.lineStrong
    }
}
