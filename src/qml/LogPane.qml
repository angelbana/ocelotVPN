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

// Everything the program and the openconnect library have said, newest at the
// bottom. When a connection fails this is the screen that answers why, so it is
// one click away rather than behind a menu.
Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding
        spacing: Math.round(11 * Theme.scale)

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: qsTr("Activity log")
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.weight: Font.Bold
            }

            Item {
                Layout.fillWidth: true
            }

            GhostButton {
                glyph: "copy"
                text: qsTr("Copy all")
                onClicked: controller.copyToClipboard(logModel.text())
            }

            GhostButton {
                glyph: "trash"
                text: qsTr("Clear")
                onClicked: logModel.clear()
            }

            GhostButton {
                glyph: autoScroll.checked ? "check" : "arrowDown"
                text: qsTr("Follow")
                selected: autoScroll.checked
                onClicked: autoScroll.checked = !autoScroll.checked
            }
        }

        QtObject {
            id: autoScroll

            property bool checked: true
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 1

            ListView {
                id: logView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: logModel
                spacing: 3
                topMargin: Math.round(10 * Theme.scale)
                bottomMargin: Math.round(10 * Theme.scale)

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                onCountChanged: if (autoScroll.checked) positionViewAtEnd()

                delegate: RowLayout {
                    id: logRow

                    required property string time
                    required property string text

                    width: logView.width - Math.round(12 * Theme.scale)
                    x: Math.round(12 * Theme.scale)
                    spacing: Math.round(12 * Theme.scale)

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: logRow.time
                        color: Theme.faint
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.monoFamily
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.rightMargin: Math.round(16 * Theme.scale)
                        text: logRow.text
                        color: Theme.ink
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.monoFamily
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }

                // An empty log at start is normal, and saying so is better than
                // an empty rectangle that looks like a fault.
                Text {
                    anchors.centerIn: parent
                    visible: logView.count === 0
                    text: qsTr("Nothing has happened yet.")
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }
        }
    }
}
