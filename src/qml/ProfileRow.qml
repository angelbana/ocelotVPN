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
import QtQuick.Layouts

// One profile in a list: its character, its name, where it dials, and a dot when
// it is the one connected.
AbstractButton {
    id: root

    property string name: ""
    property string emoji: ""
    property string subtitle: ""
    property bool selected: false
    property bool active: false
    property color statusColor: Theme.ok
    property bool busy: false
    // The right-hand side is a shortcut hint in the popover and nothing in the
    // window, where the same actions are a menu away.
    property string shortcutHint: ""
    property bool allowActions: true

    signal editRequested()
    signal removeRequested()
    signal duplicateRequested()

    property string lastConnected: ""

    implicitHeight: Math.round(40 * Theme.scale)
    hoverEnabled: true

    ToolTip.visible: hovered && ToolTip.text.length > 0
    ToolTip.delay: 900
    ToolTip.text: root.lastConnected.length > 0
        ? qsTr("Last connected %1").arg(root.lastConnected) : ""

    background: Rectangle {
        radius: Theme.radiusSmall
        color: root.active ? Theme.statusSoftColor(controller.status)
            : root.down ? Theme.cardHover
            : root.hovered ? Theme.cardHover
            : root.selected ? Theme.accentSoft
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        // A bar down the left of the selected row: at a glance it reads as "this
        // is the one" even where the fill is subtle.
        Rectangle {
            visible: root.selected
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(2 * Theme.scale)
            width: Math.max(2, Math.round(2.5 * Theme.scale))
            height: Math.round(18 * Theme.scale)
            radius: width / 2
            color: Theme.accent
        }
    }

    contentItem: RowLayout {
        spacing: 8

        Text {
            Layout.leftMargin: Math.round(7 * Theme.scale)
            text: root.emoji
            font.pixelSize: Math.round(15 * Theme.scale)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.name
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }

        PulseDot {
            visible: root.active
            tint: root.statusColor
            active: root.busy
            dotSize: Math.round(6 * Theme.scale)
        }

        Text {
            Layout.rightMargin: Math.round(8 * Theme.scale)
            visible: !root.active && root.shortcutHint.length > 0
            text: root.shortcutHint
            color: root.hovered ? Theme.muted : Qt.alpha(Theme.faint, 0.6)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
        }

        GhostButton {
            Layout.rightMargin: Math.round(4 * Theme.scale)
            visible: root.allowActions && root.hovered && !root.active
            glyph: "pencil"
            onClicked: root.editRequested()
            ToolTip.text: qsTr("Edit this profile")
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: root.allowActions
        onTapped: menu.popup()
    }

    Menu {
        id: menu

        MenuItem {
            text: qsTr("Connect")
            enabled: controller.status === Theme.statusDisconnected
            onTriggered: controller.connectToProfile(root.name)
        }

        MenuItem {
            text: qsTr("Edit…")
            enabled: controller.status === Theme.statusDisconnected
            onTriggered: root.editRequested()
        }

        MenuItem {
            text: qsTr("Duplicate")
            onTriggered: root.duplicateRequested()
        }

        MenuItem {
            text: qsTr("Remove…")
            enabled: controller.status === Theme.statusDisconnected
            onTriggered: root.removeRequested()
        }
    }
}
