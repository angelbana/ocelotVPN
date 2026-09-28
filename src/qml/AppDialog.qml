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

Popup {
    id: root

    property string title: ""
    property string message: ""
    property string acceptText: qsTr("Close")
    property bool destructive: false

    signal accepted()

    function show(title, message) {
        root.title = title;
        root.message = message;
        root.open();
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(Math.round(420 * Theme.scale), parent ? parent.width - 32 : Math.round(420 * Theme.scale))
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: Theme.scrim
    }

    background: Rectangle {
        radius: Theme.radiusLarge
        color: Theme.raised
        border.width: 1
        border.color: Theme.line
    }

    contentItem: ColumnLayout {
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.bottomMargin: 0
            text: root.title
            color: Theme.ink
            font.pixelSize: 17
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.topMargin: 8
            text: root.message
            color: Theme.muted
            font.pixelSize: Theme.fontNormal
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.line
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                text: qsTr("Cancel")
                visible: root.destructive
                onClicked: root.close()
            }

            AppButton {
                text: root.acceptText
                kind: root.destructive ? "solidDanger" : "primary"
                onClicked: {
                    root.close();
                    root.accepted();
                }
            }
        }
    }
}
