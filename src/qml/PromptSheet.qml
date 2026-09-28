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

    // keep in sync with VpnController::PromptType
    readonly property int promptInput: 0
    readonly property int promptPassword: 1
    readonly property int promptChoice: 2
    readonly property int promptConfirm: 3

    property int promptType: promptInput
    property var request: ({})
    property bool detailsExpanded: false

    function ask(type, request) {
        root.promptType = type;
        root.request = request;
        root.detailsExpanded = false;
        field.text = "";
        choices.currentIndex = 0;
        root.open();
        if (type === promptInput || type === promptPassword)
            field.forceActiveFocus();
    }

    function answer(accepted) {
        let text = "";
        if (accepted) {
            if (promptType === promptChoice)
                text = choices.currentText;
            else if (promptType === promptInput || promptType === promptPassword)
                text = field.text;
        }
        root.close();
        controller.answerPrompt(accepted, text);
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(Math.round(440 * Theme.scale), parent ? parent.width - 32 : Math.round(440 * Theme.scale))
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose

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

        focus: true
        Keys.onEscapePressed: root.answer(false)

        Text {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.bottomMargin: 0
            text: root.request.title !== undefined ? root.request.title : ""
            color: Theme.ink
            font.pixelSize: 17
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.topMargin: 10
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: root.request.banner !== undefined ? root.request.banner : ""
                visible: text.length > 0
                color: Theme.muted
                font.pixelSize: Theme.fontNormal
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: root.request.message !== undefined ? root.request.message : ""
                visible: text.length > 0
                color: Theme.muted
                font.pixelSize: Theme.fontNormal
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: root.request.label !== undefined ? root.request.label : ""
                visible: text.length > 0
                color: root.promptType === root.promptConfirm ? Theme.ink : Theme.muted
                font.pixelSize: root.promptType === root.promptConfirm ? Theme.fontNormal : Theme.fontSmall
                font.weight: root.promptType === root.promptConfirm ? Font.Normal : Font.DemiBold
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
            }

            AppField {
                id: field

                Layout.fillWidth: true
                visible: root.promptType === root.promptInput || root.promptType === root.promptPassword
                echoMode: root.promptType === root.promptPassword ? TextInput.Password : TextInput.Normal
                onAccepted: root.answer(true)
            }

            AppComboBox {
                id: choices

                Layout.fillWidth: true
                visible: root.promptType === root.promptChoice
                model: root.request.choices !== undefined ? root.request.choices : []
            }

            AppButton {
                Layout.alignment: Qt.AlignLeft
                compact: true
                kind: "flat"
                visible: root.request.details !== undefined && root.request.details.length > 0
                text: root.detailsExpanded ? qsTr("Hide certificate details") : qsTr("Show certificate details")
                onClicked: root.detailsExpanded = !root.detailsExpanded
            }

            ScrollView {
                ScrollBar.vertical: AppScrollBar {}
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(160 * Theme.scale)
                visible: root.detailsExpanded
                clip: true

                TextArea {
                    text: root.request.details !== undefined ? root.request.details : ""
                    readOnly: true
                    color: Theme.ink
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.monoFamily
                    wrapMode: TextArea.WrapAnywhere

                    background: Rectangle {
                        radius: Theme.radius
                        color: Theme.sunken
                        border.width: 1
                        border.color: Theme.line
                    }
                }
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
                onClicked: root.answer(false)
            }

            AppButton {
                kind: "primary"
                text: root.request.okText !== undefined && root.request.okText.length > 0
                    ? root.request.okText
                    : qsTr("Continue")
                onClicked: root.answer(true)
            }
        }
    }
}
