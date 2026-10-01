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

// The screen the program opens on: what the connection is doing, the one button
// that changes it, and - once it is up - what the tunnel actually got.
Item {
    id: root

    signal logRequested()
    signal editRequested()
    signal newProfileRequested()

    readonly property int status: controller.status
    readonly property bool connected: status === Theme.statusConnected
    readonly property bool hasProfile: controller.currentProfile !== ""

    ScrollView {
        ScrollBar.vertical: AppScrollBar {}
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: root.width
            spacing: Math.round(13 * Theme.scale)

            // ------------------------------------------------ the state, large
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                Layout.topMargin: Theme.padding
                padding: Math.round(16 * Theme.scale)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(16 * Theme.scale)

                    Mascot {
                        mood: mainWindow.mascotMood
                        size: Math.round(104 * Theme.scale)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Math.round(6 * Theme.scale)

                        Text {
                            Layout.fillWidth: true
                            text: root.hasProfile ? controller.currentProfile : qsTr("Ocelot")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHuge
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 7

                            PulseDot {
                                tint: Theme.statusColor(root.status)
                                active: Theme.statusIsBusy(root.status)
                            }

                            Text {
                                text: controller.reconnectPending
                                    ? (controller.reconnectAttempt > 1
                                        ? qsTr("The connection dropped — dialling again (try %1)")
                                            .arg(controller.reconnectAttempt)
                                        : qsTr("The connection dropped — dialling again shortly"))
                                    : Theme.statusLabel(root.status)
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                            }
                        }

                        RowLayout {
                            Layout.topMargin: 2
                            spacing: 6
                            visible: root.connected

                            Pill {
                                text: controller.uptime
                                tint: Theme.ok
                                glyph: "clock"
                            }

                            Pill {
                                visible: controller.dtlsCipher !== ""
                                text: qsTr("DTLS")
                                tint: Theme.ok
                                glyph: "bolt"
                            }

                            Pill {
                                // The address alone: the mask belongs in the
                                // details, where there is room for it.
                                visible: controller.ip !== ""
                                text: controller.ip.split("/")[0]
                                tint: Theme.muted
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !root.connected
                            text: root.hasProfile ? controller.gateway
                                : qsTr("Add a profile to tell Ocelot which VPN to dial.")
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            // An address is cut off at the end without losing
                            // its point; a sentence is not, so it wraps.
                            wrapMode: root.hasProfile ? Text.NoWrap : Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        spacing: 6

                        ChunkyButton {
                            id: actionButton

                            Layout.preferredWidth: Math.round(172 * Theme.scale)

                            enabled: root.hasProfile && root.status !== Theme.statusDisconnecting
                            busy: Theme.statusIsBusy(root.status)
                            glyph: root.status === Theme.statusConnecting ? "close" : "power"
                            tint: root.connected ? Theme.danger
                                : root.status === Theme.statusConnecting ? Theme.muted
                                : Theme.accent
                            text: root.connected ? qsTr("Disconnect")
                                : root.status === Theme.statusConnecting ? qsTr("Cancel")
                                : root.status === Theme.statusDisconnecting ? qsTr("Disconnecting")
                                : qsTr("Connect")

                            onClicked: {
                                if (root.status === Theme.statusDisconnected)
                                    controller.connectVpn();
                                else
                                    controller.disconnectVpn();
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.connected && controller.protocolShortName !== ""
                            text: qsTr("via %1").arg(controller.protocolShortName)
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }
            }

            // -------------------------------------------- a tunnel without DNS
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                visible: root.connected && controller.dns === ""
                tint: Theme.dangerSoft
                padding: Math.round(12 * Theme.scale)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    Glyph {
                        Layout.alignment: Qt.AlignTop
                        name: "warning"
                        color: Theme.danger
                        size: Math.round(16 * Theme.scale)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: qsTr("Connected, but no DNS servers were applied")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Traffic will route, but names on the VPN will not resolve. "
                                + "Either the server sent no resolvers, or the vpnc script could "
                                + "not apply them.")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            wrapMode: Text.WordWrap
                        }

                        GhostButton {
                            glyph: "log"
                            text: qsTr("Open the log")
                            onClicked: root.logRequested()
                        }
                    }
                }
            }

            // ------------------------------------------------------ throughput
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                visible: root.connected
                padding: Math.round(14 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Throughput")
                    trailing: controller.dtlsCipher !== "" ? controller.dtlsCipher : controller.cstpCipher
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: Math.round(14 * Theme.scale)

                    StatTile {
                        Layout.fillWidth: true
                        glyph: "arrowDown"
                        label: qsTr("Download")
                        value: Theme.formatRate(controller.rxRate)
                        detail: qsTr("%1 in total").arg(controller.received)
                        tint: Theme.ok
                    }

                    StatTile {
                        Layout.fillWidth: true
                        glyph: "arrowUp"
                        label: qsTr("Upload")
                        value: Theme.formatRate(controller.txRate)
                        detail: qsTr("%1 in total").arg(controller.sent)
                        tint: Theme.busy
                    }

                    StatTile {
                        Layout.fillWidth: true
                        glyph: "clock"
                        label: qsTr("Uptime")
                        value: controller.uptime
                        detail: controller.currentProfile
                        tint: Theme.accent
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(70 * Theme.scale)
                    Layout.topMargin: 4
                    radius: Theme.radiusSmall
                    color: Theme.sunken

                    ThroughputChart {
                        anchors.fill: parent
                        anchors.margins: Math.round(3 * Theme.scale)
                        rxSamples: Telemetry.rx
                        txSamples: Telemetry.tx
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 1
                    color: Theme.line
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * Theme.scale)

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("IPv4 address")
                        value: controller.ip
                        mono: true
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        visible: controller.ip6 !== ""
                        label: qsTr("IPv6 address")
                        value: controller.ip6
                        mono: true
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("DNS servers")
                        value: controller.dns !== "" ? controller.dns : qsTr("none applied")
                        mono: controller.dns !== ""
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        visible: controller.searchDomains !== ""
                        label: qsTr("Search domains")
                        value: controller.searchDomains
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("CSTP cipher")
                        value: controller.cstpCipher
                        mono: true
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        visible: controller.dtlsCipher !== ""
                        label: qsTr("DTLS cipher")
                        value: controller.dtlsCipher
                        mono: true
                    }
                }
            }

            // ----------------------------------------------- the chosen profile
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                visible: root.hasProfile
                padding: Math.round(14 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("This profile")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: controller.profileEmoji
                        font.pixelSize: Math.round(22 * Theme.scale)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: controller.currentProfile
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: controller.gateway
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                        }
                    }

                    GhostButton {
                        glyph: "pencil"
                        text: qsTr("Edit")
                        enabled: root.status === Theme.statusDisconnected
                        onClicked: root.editRequested()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: Math.round(6 * Theme.scale)

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("Protocol")
                        value: controller.protocolName
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        visible: profileFacts.lastConnected.length > 0
                        label: qsTr("Last connected")
                        value: profileFacts.lastConnected
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("Name resolution")
                        value: profileFacts.dnsMode === 1 ? qsTr("everything through the VPN")
                            : qsTr("as the server asks")
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        label: qsTr("Connects without asking")
                        value: profileFacts.remembers ? qsTr("yes, the password is remembered")
                            : qsTr("no, it asks every time")
                    }
                }

                QtObject {
                    id: profileFacts

                    property bool remembers: false
                    property int dnsMode: 0
                    property string lastConnected: ""

                    function refresh() {
                        if (controller.currentProfile === "") {
                            remembers = false;
                            dnsMode = 0;
                            lastConnected = "";
                            return;
                        }

                        const profile = controller.loadProfile(controller.currentProfile);
                        remembers = profile.batchMode === true
                            && String(profile.password || "").length > 0;
                        dnsMode = profile.dnsMode || 0;

                        lastConnected = "";
                        const entries = controller.profileEntries;
                        for (let i = 0; i < entries.length; i++) {
                            if (entries[i].name === controller.currentProfile) {
                                lastConnected = Theme.formatWhen(entries[i].lastConnected);
                                break;
                            }
                        }
                    }
                }

                Connections {
                    target: controller
                    function onCurrentProfileChanged() { profileFacts.refresh(); }
                    function onProfilesChanged() { profileFacts.refresh(); }
                }

                Component.onCompleted: profileFacts.refresh()
            }

            // ------------------------------------------------- nothing set up yet
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(30 * Theme.scale)
                visible: !root.hasProfile
                spacing: Math.round(10 * Theme.scale)

                Mascot {
                    Layout.alignment: Qt.AlignHCenter
                    mood: "sleepy"
                    size: Math.round(92 * Theme.scale)
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    text: qsTr("No profile yet")
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMedium
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    // Centred within the width it has, not centred at whatever
                    // width the sentence happens to be: the long one used to
                    // reach past both edges of the pane.
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    text: qsTr("A profile is one VPN: its address, who you sign in as, and how.")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                ChunkyButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.preferredWidth: Math.round(190 * Theme.scale)
                    glyph: "plus"
                    text: qsTr("Add a profile")
                    onClicked: root.newProfileRequested()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.padding
            }
        }
    }
}
