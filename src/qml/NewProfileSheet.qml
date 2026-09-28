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

    property bool nameEdited: false

    signal customizeRequested(string name)

    function nameFromGateway(gateway) {
        let host = gateway.trim().replace(/^https?:\/\//i, "");
        const slash = host.indexOf("/");
        if (slash !== -1)
            host = host.substring(0, slash);
        return host;
    }

    function save() {
        const profile = {
            "name": nameField.text.trim().length > 0 ? nameField.text.trim() : root.nameFromGateway(gatewayField.text),
            "gateway": gatewayField.text,
            "protocol": protocolBox.currentValue,
            "originalName": ""
        };

        const error = controller.saveProfile(profile);
        if (error.length > 0) {
            errorText.text = error;
            return;
        }

        root.close();
        if (customizeBox.checked)
            root.customizeRequested(profile.name);
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(Math.round(440 * Theme.scale), parent ? parent.width - 32 : Math.round(440 * Theme.scale))
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

    onOpened: {
        nameField.text = "";
        gatewayField.text = "";
        customizeBox.checked = false;
        errorText.text = "";
        nameEdited = false;
        protocolBox.currentIndex = 0;
        gatewayField.forceActiveFocus();
    }

    contentItem: ColumnLayout {
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.bottomMargin: 0
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: qsTr("New profile")
                color: Theme.ink
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("You can change every detail later in the profile editor.")
                color: Theme.muted
                font.pixelSize: Theme.fontNormal
                wrapMode: Text.WordWrap
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("Gateway")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }

                AppField {
                    id: gatewayField

                    Layout.fillWidth: true
                    mono: true
                    placeholderText: "https://my_server[:443]/[usergroup]"
                    onTextChanged: {
                        if (!root.nameEdited)
                            nameField.text = root.nameFromGateway(text);
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("Name")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }

                AppField {
                    id: nameField

                    Layout.fillWidth: true
                    placeholderText: qsTr("User friendly unique connection name")
                    onTextEdited: root.nameEdited = true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("VPN protocol")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }

                AppComboBox {
                    id: protocolBox

                    Layout.fillWidth: true
                    model: controller.protocols()
                    textRole: "label"
                    valueRole: "name"
                }
            }

            CheckBox {
                id: customizeBox

                text: qsTr("Open the full editor after creating")

                indicator: Rectangle {
                    width: 16
                    height: 16
                    y: parent.height / 2 - height / 2
                    radius: 4
                    color: customizeBox.checked ? Theme.accent : Theme.surface
                    border.width: 1
                    border.color: customizeBox.checked ? Theme.accent : Theme.lineStrong

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Theme.accentInk
                        font.pixelSize: 11
                        visible: customizeBox.checked
                    }
                }

                contentItem: Text {
                    leftPadding: 22
                    text: customizeBox.text
                    color: Theme.ink
                    font.pixelSize: Theme.fontNormal
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                id: errorText

                Layout.fillWidth: true
                visible: text.length > 0
                color: Theme.danger
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
            }
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
                onClicked: root.close()
            }

            AppButton {
                kind: "primary"
                text: qsTr("Create profile")
                onClicked: root.save()
            }
        }
    }
}
