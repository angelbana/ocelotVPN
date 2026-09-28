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
import QtQuick.Dialogs
import QtQuick.Layouts

Popup {
    id: root

    property var profile: ({})
    property string emoji: ""
    property int tab: 0
    property bool clearCaCert: false
    property bool clearClientCert: false
    property bool clearClientKey: false
    property bool clearServerPin: false

    signal removeRequested(string name)

    function edit(name) {
        root.profile = controller.loadProfile(name);
        root.tab = 0;
        root.clearCaCert = false;
        root.clearClientCert = false;
        root.clearClientKey = false;
        root.clearServerPin = false;

        nameField.text = profile.name;
        gatewayField.text = profile.gateway;
        usernameField.text = profile.username;
        passwordField.text = profile.password !== undefined ? profile.password : "";
        root.emoji = profile.emoji !== undefined && profile.emoji.length > 0
            ? profile.emoji : controller.emojiChoices()[0];
        groupnameField.text = profile.groupname;
        tokenField.text = profile.tokenStr;
        interfaceField.text = profile.interfaceName;
        vpncField.text = profile.vpncScript;
        reconnectField.text = profile.reconnectTimeout;
        dtlsField.text = profile.dtlsAttemptPeriod;
        caCertField.text = "";
        userCertField.text = "";
        userKeyField.text = "";
        serverPinText.text = profile.serverCertPin;
        caPinText.text = profile.caCertPin;
        clientPinText.text = profile.clientCertPin;
        batchToggle.checked = profile.batchMode;
        minimizeToggle.checked = profile.minimizeOnConnect;
        disableUdpToggle.checked = profile.disableUdp;
        proxyToggle.checked = profile.useProxy;
        protocolBox.currentIndex = protocolBox.indexOfValue(profile.protocol);
        tokenBox.currentIndex = tokenBox.indexOfValue(profile.tokenType);
        logLevelBox.currentIndex = logLevelBox.indexOfValue(profile.logLevel);
        dnsModeBox.currentIndex = profile.dnsMode === 1 ? 1 : 0;
        errorText.text = "";

        if (profile.interfaceNameMaxLength > 0)
            interfaceField.maximumLength = profile.interfaceNameMaxLength;

        root.open();
    }

    function save() {
        const edited = {
            "name": nameField.text,
            "originalName": profile.originalName,
            "gateway": gatewayField.text,
            "username": usernameField.text,
            "password": passwordField.text,
            "emoji": root.emoji,
            "groupname": groupnameField.text,
            "protocol": protocolBox.currentValue,
            "tokenType": tokenBox.currentValue,
            "tokenStr": tokenField.text,
            "interfaceName": interfaceField.text,
            "vpncScript": vpncField.text,
            "logLevel": logLevelBox.currentValue,
            "dnsMode": dnsModeBox.currentIndex,
            "batchMode": batchToggle.checked,
            "minimizeOnConnect": minimizeToggle.checked,
            "disableUdp": disableUdpToggle.checked,
            "useProxy": proxyToggle.checked,
            "reconnectTimeout": parseInt(reconnectField.text) || 300,
            "dtlsAttemptPeriod": parseInt(dtlsField.text) || 25,
            "caCertFile": caCertField.text,
            "clientCertFile": userCertField.text,
            "clientKeyFile": userKeyField.text,
            "clearCaCert": root.clearCaCert,
            "clearClientCert": root.clearClientCert,
            "clearClientKey": root.clearClientKey,
            "clearServerPin": root.clearServerPin
        };

        const error = controller.saveProfile(edited);
        if (error.length > 0) {
            errorText.text = error;
            root.tab = 0;
            return;
        }

        root.close();
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(Math.round(600 * Theme.scale), parent ? parent.width - 32 : Math.round(600 * Theme.scale))
    height: Math.min(Math.round(560 * Theme.scale), parent ? parent.height - 32 : Math.round(560 * Theme.scale))
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

    component FieldLabel: Text {
        Layout.fillWidth: true
        color: Theme.muted
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    // one label with its control; stays together when the form collapses
    // into a single column
    component Field: ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: Math.round(6 * Theme.scale)
    }

    component TabHeader: AbstractButton {
        id: tabHeader

        property int index: 0

        implicitHeight: Math.round(36 * Theme.scale)
        implicitWidth: label.implicitWidth + Math.round(20 * Theme.scale)
        onClicked: root.tab = index

        background: Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: root.tab === tabHeader.index ? Theme.accent : "transparent"
        }

        contentItem: Text {
            id: label
            text: tabHeader.text
            color: root.tab === tabHeader.index ? Theme.ink : Theme.muted
            font.pixelSize: Theme.fontNormal
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    FileDialog {
        id: certDialog

        property var target: null

        title: qsTr("Open certificate")
        nameFilters: [qsTr("Certificate files (*.crt *.pem *.der *.p12)"), qsTr("All files (*)")]
        onAccepted: if (target) target.text = decodeURIComponent(selectedFile.toString().replace("file:///", ""))
    }

    FileDialog {
        id: keyDialog

        title: qsTr("Open private key")
        nameFilters: [qsTr("Private key files (*.key *.pem *.der *.p8 *.p12)"), qsTr("All files (*)")]
        onAccepted: userKeyField.text = decodeURIComponent(selectedFile.toString().replace("file:///", ""))
    }

    FileDialog {
        id: scriptDialog

        title: qsTr("Select vpnc-script")
        onAccepted: vpncField.text = decodeURIComponent(selectedFile.toString().replace("file:///", ""))
    }

    contentItem: ColumnLayout {
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.margins: Math.round(20 * Theme.scale)
            Layout.bottomMargin: 4
            text: profile.originalName !== undefined && profile.originalName.length > 0
                ? qsTr("Edit %1").arg(profile.originalName)
                : qsTr("New profile")
            color: Theme.ink
            font.pixelSize: Math.round(17 * Theme.scale)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(14 * Theme.scale)
            spacing: 4

            TabHeader {
                index: 0
                text: qsTr("Connection")
            }

            TabHeader {
                index: 1
                text: qsTr("Certificates")
            }

            TabHeader {
                index: 2
                text: qsTr("Advanced")
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.line
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Connection
            GridLayout {
                id: connectionGrid

                width: root.width - Math.round(40 * Theme.scale)
                x: Math.round(20 * Theme.scale)
                y: Math.round(16 * Theme.scale)
                visible: root.tab === 0
                // the two-column form collapses to one column in a narrow window
                columns: root.width < Theme.narrowWidth ? 1 : 2
                columnSpacing: Math.round(14 * Theme.scale)
                rowSpacing: Math.round(10 * Theme.scale)

                Field {
                    FieldLabel {
                        text: qsTr("Name")
                    }

                    AppField {
                        id: nameField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("Character")
                    }

                    // A picture for the profile without a picture to find: the
                    // lists show this, and one glance tells them apart.
                    Flow {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: controller.emojiChoices()

                            delegate: AbstractButton {
                                id: emojiButton

                                required property string modelData

                                implicitWidth: Math.round(30 * Theme.scale)
                                implicitHeight: Math.round(30 * Theme.scale)
                                onClicked: root.emoji = modelData

                                background: Rectangle {
                                    radius: Theme.radiusSmall
                                    color: root.emoji === emojiButton.modelData
                                        ? Theme.accentSoft : "transparent"
                                    border.width: root.emoji === emojiButton.modelData ? 1 : 0
                                    border.color: Theme.accent
                                }

                                contentItem: Text {
                                    text: emojiButton.modelData
                                    font.pixelSize: Math.round(16 * Theme.scale)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("VPN protocol")
                    }

                    AppComboBox {
                        id: protocolBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        model: controller.protocols()
                        textRole: "label"
                        valueRole: "name"
                    }
                }

                Field {
                    Layout.columnSpan: connectionGrid.columns

                    FieldLabel {
                        text: qsTr("Gateway")
                    }

                    AppField {
                        id: gatewayField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        placeholderText: "https://my_server[:443]/[usergroup]"
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

                Field {
                    FieldLabel {
                        text: qsTr("Username")
                    }

                    AppField {
                        id: usernameField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                }

                Field {
                    Layout.columnSpan: connectionGrid.columns

                    FieldLabel {
                        text: qsTr("Password")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        AppField {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            enabled: batchToggle.checked
                            echoMode: TextInput.Password
                            placeholderText: batchToggle.checked
                                ? qsTr("The password for this server")
                                : qsTr("Asked for at every connection")
                        }

                        AppToggle {
                            id: batchToggle
                            Layout.preferredWidth: Math.round(190 * Theme.scale)
                            text: qsTr("Remember it")
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Windows seals a remembered password to this account on this "
                            + "computer, so it cannot be read anywhere else — and turning this "
                            + "off deletes it.")
                        color: Theme.faint
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("Group name")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppField {
                            id: groupnameField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                        }

                        AppButton {
                            text: qsTr("Clear")
                            enabled: groupnameField.text.length > 0
                            onClicked: groupnameField.text = ""
                        }
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("OTP token")
                    }

                    AppComboBox {
                        id: tokenBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        model: controller.tokenModes()
                        textRole: "label"
                        valueRole: "value"
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("Token secret")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppField {
                            id: tokenField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            mono: true
                            placeholderText: qsTr("0x... or base32:...")
                        }

                        AppButton {
                            text: qsTr("Clear")
                            enabled: tokenField.text.length > 0
                            onClicked: {
                                tokenField.text = "";
                                tokenBox.currentIndex = tokenBox.indexOfValue(-1);
                            }
                        }
                    }
                }
            }

            // Certificates
            ColumnLayout {
                width: root.width - Math.round(40 * Theme.scale)
                x: Math.round(20 * Theme.scale)
                y: Math.round(16 * Theme.scale)
                visible: root.tab === 1
                spacing: Math.round(6 * Theme.scale)

                FieldLabel {
                    text: qsTr("CA certificate")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppField {
                        id: caCertField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        placeholderText: qsTr("System trust store")
                    }

                    AppButton {
                        text: qsTr("Browse...")
                        onClicked: {
                            certDialog.target = caCertField;
                            certDialog.open();
                        }
                    }

                    AppButton {
                        text: qsTr("Clear")
                        enabled: caPinText.text.length > 0 || caCertField.text.length > 0
                        onClicked: {
                            caCertField.text = "";
                            caPinText.text = "";
                            root.clearCaCert = true;
                        }
                    }
                }

                Text {
                    id: caPinText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    color: Theme.faint
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.monoFamily
                    wrapMode: Text.WrapAnywhere
                }

                FieldLabel {
                    Layout.topMargin: 10
                    text: qsTr("Trusted server certificate")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        id: serverPinText
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: ""
                        color: text.length > 0 ? Theme.ink : Theme.faint
                        font.pixelSize: Theme.fontSmall
                        font.family: Theme.monoFamily
                        wrapMode: Text.WrapAnywhere
                    }

                    AppButton {
                        text: qsTr("Forget")
                        enabled: serverPinText.text.length > 0
                        onClicked: {
                            serverPinText.text = "";
                            root.clearServerPin = true;
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Saved the first time you accepted this server. Forget it if the server's certificate changed.")
                    color: Theme.faint
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.WordWrap
                }

                FieldLabel {
                    Layout.topMargin: 10
                    text: qsTr("User certificate")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppField {
                        id: userCertField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        placeholderText: clientPinText.text.length > 0 ? qsTr("Stored in the profile") : qsTr("None")
                    }

                    AppButton {
                        text: qsTr("Browse...")
                        onClicked: {
                            certDialog.target = userCertField;
                            certDialog.open();
                        }
                    }

                    AppButton {
                        text: qsTr("Clear")
                        enabled: clientPinText.text.length > 0 || userCertField.text.length > 0
                        onClicked: {
                            userCertField.text = "";
                            clientPinText.text = "";
                            root.clearClientCert = true;
                        }
                    }
                }

                Text {
                    id: clientPinText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    color: Theme.faint
                    font.pixelSize: Theme.fontSmall
                    font.family: Theme.monoFamily
                    wrapMode: Text.WrapAnywhere
                }

                FieldLabel {
                    Layout.topMargin: 10
                    text: qsTr("User key")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppField {
                        id: userKeyField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        placeholderText: qsTr("None")
                    }

                    AppButton {
                        text: qsTr("Browse...")
                        onClicked: keyDialog.open()
                    }

                    AppButton {
                        text: qsTr("Clear")
                        enabled: userKeyField.text.length > 0
                        onClicked: {
                            userKeyField.text = "";
                            root.clearClientKey = true;
                        }
                    }
                }

                FieldLabel {
                    Layout.topMargin: 10
                    text: qsTr("Certificate from the system store")
                    visible: systemCerts.count > 0
                }

                ListView {
                    id: systemCerts

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, Math.round(120 * Theme.scale))
                    visible: count > 0
                    clip: true
                    model: controller.systemCertificates()

                    delegate: AbstractButton {
                        id: certItem

                        required property var modelData

                        width: systemCerts.width
                        height: Math.round(28 * Theme.scale)
                        onClicked: {
                            userCertField.text = certItem.modelData.certUrl;
                            userKeyField.text = certItem.modelData.keyUrl;
                        }

                        contentItem: Text {
                            text: certItem.modelData.label
                            color: Theme.ink
                            font.pixelSize: Theme.fontSmall
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: certItem.hovered ? Theme.sunken : "transparent"
                        }
                    }
                }
            }

            // Advanced
            GridLayout {
                id: advancedGrid

                width: root.width - Math.round(40 * Theme.scale)
                x: Math.round(20 * Theme.scale)
                y: Math.round(16 * Theme.scale)
                visible: root.tab === 2
                columns: root.width < Theme.narrowWidth ? 1 : 2
                columnSpacing: Math.round(14 * Theme.scale)
                rowSpacing: Math.round(10 * Theme.scale)

                Field {
                    FieldLabel {
                        text: qsTr("Interface name")
                    }

                    AppField {
                        id: interfaceField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        placeholderText: qsTr("Automatic")
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("Log level")
                    }

                    AppComboBox {
                        id: logLevelBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        model: [{ "value": -1, "label": qsTr("Application default") }].concat(controller.logLevels())
                        textRole: "label"
                        valueRole: "value"
                    }
                }

                Field {
                    Layout.columnSpan: advancedGrid.columns

                    FieldLabel {
                        text: qsTr("vpnc-script")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppField {
                            id: vpncField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            mono: true
                            placeholderText: qsTr("Bundled vpnc-script")
                        }

                        AppButton {
                            text: qsTr("Browse...")
                            onClicked: scriptDialog.open()
                        }
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("Reconnect timeout, s")
                    }

                    AppField {
                        id: reconnectField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 0; top: 100000 }
                    }
                }

                Field {
                    FieldLabel {
                        text: qsTr("DTLS attempt period, s")
                    }

                    AppField {
                        id: dtlsField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        mono: true
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 0; top: 100000 }
                    }
                }

                AppToggle {
                    id: minimizeToggle
                    Layout.columnSpan: advancedGrid.columns
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(8 * Theme.scale)
                    text: qsTr("Minimize on connect")
                }

                Field {
                    Layout.columnSpan: advancedGrid.columns

                    FieldLabel {
                        text: qsTr("Name resolution")
                    }

                    AppComboBox {
                        id: dnsModeBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        model: [qsTr("As the server asks (split)"),
                            qsTr("Everything through the VPN")]
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Qt.platform.os === "windows"
                            ? qsTr("Split sends only the domains the server named through the "
                                + "tunnel, and leaves the rest to your usual resolvers.")
                            : qsTr("Only Windows honours this; elsewhere the vpnc script decides.")
                        color: Theme.faint
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }

                AppToggle {
                    id: disableUdpToggle
                    Layout.columnSpan: advancedGrid.columns
                    Layout.fillWidth: true
                    text: qsTr("Disable UDP")
                    description: qsTr("Use only TLS; skips DTLS.")
                }

                AppToggle {
                    id: proxyToggle
                    Layout.columnSpan: advancedGrid.columns
                    Layout.fillWidth: true
                    text: qsTr("Use system proxy")
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
            Layout.margins: Math.round(16 * Theme.scale)
            spacing: 8

            AppButton {
                kind: "danger"
                text: qsTr("Remove profile")
                visible: profile.originalName !== undefined && profile.originalName.length > 0
                onClicked: {
                    root.close();
                    root.removeRequested(profile.originalName);
                }
            }

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            AppButton {
                kind: "primary"
                text: qsTr("Save")
                onClicked: root.save()
            }
        }
    }
}
