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

// Who wrote this, what it is built on, and where the Mac one lives.
Item {
    id: root

    signal licenseRequested()

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: root.width
            spacing: Math.round(13 * Theme.scale)

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                Layout.topMargin: Theme.padding
                padding: Math.round(16 * Theme.scale)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(14 * Theme.scale)

                    Mascot {
                        Layout.alignment: Qt.AlignTop
                        mood: "happy"
                        size: Math.round(88 * Theme.scale)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: Qt.application.displayName
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHuge
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: controller.aboutText()
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            textFormat: Text.RichText
                            wrapMode: Text.WordWrap
                            onLinkActivated: link => Qt.openUrlExternally(link)

                            HoverHandler {
                                cursorShape: parent.hoveredLink.length > 0
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6

                    GhostButton {
                        glyph: "globe"
                        text: qsTr("Project page")
                        onClicked: Qt.openUrlExternally(controller.repoUrl)
                    }

                    GhostButton {
                        glyph: "question"
                        text: qsTr("Report an issue")
                        onClicked: Qt.openUrlExternally(controller.issuesUrl)
                    }

                    GhostButton {
                        glyph: "log"
                        text: qsTr("License")
                        onClicked: root.licenseRequested()
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                padding: Math.round(14 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Built on")
                }

                Text {
                    Layout.fillWidth: true
                    text: controller.licenseText()
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    textFormat: Text.RichText
                    wrapMode: Text.WordWrap
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.padding
            }
        }
    }
}
