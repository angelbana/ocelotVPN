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

// What one click on the notification area icon opens: the state, the one button,
// and the profiles. Most days this is the whole program, and the window is only
// for setting things up.
//
// A window rather than a Popup, because a popup belongs to a window that is
// usually hidden; and frameless, because a title bar over the notification area
// would look like a mistake.
Window {
    id: root

    property string mood: "sleepy"

    signal windowRequested(string tab)
    signal newProfileRequested()

    readonly property int status: controller.status
    readonly property bool connected: status === Theme.statusConnected

    width: Theme.popoverWidth
    height: Math.min(layout.implicitHeight + Math.round(24 * Theme.scale),
        Screen.height - Math.round(80 * Theme.scale))
    // A tool window rather than a popup: a popup cannot be given keyboard focus
    // on Windows, and this one has buttons to tab through and a list to pick
    // from. It stays out of the taskbar all the same.
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    visible: false

    // Set once the popover has actually been given focus. Without it, a window
    // shown while another program is in front counts as inactive from the
    // start and closes itself before anyone has seen it.
    property bool everActivated: false

    function toggle() {
        if (visible) {
            hide();
        } else {
            everActivated = false;
            place();
            show();
            raise();
            requestActivate();
        }
    }

    // Which screen a point is on. With more than one monitor the notification
    // area is on one of them, and the popover belongs beside its own icon - so
    // everything here is measured against that screen rather than against the
    // several added together.
    function screenAt(px, py) {
        const screens = Qt.application.screens;
        for (let i = 0; i < screens.length; i++) {
            const candidate = screens[i];
            if (px >= candidate.virtualX && px < candidate.virtualX + candidate.width
                && py >= candidate.virtualY && py < candidate.virtualY + candidate.height) {
                return candidate;
            }
        }
        return Screen;
    }

    // Beside the icon that opened it, and inside that screen. The notification
    // area is at the bottom on most Windows machines but can be moved to any
    // edge, so the position is worked out from where the icon actually is
    // rather than assumed.
    function place() {
        const margin = Math.round(8 * Theme.scale);
        const icon = controller.trayIconGeometry();

        const host = icon.width > 0
            ? screenAt(icon.x + icon.width / 2, icon.y + icon.height / 2)
            : Screen;
        const left = host.virtualX;
        const top = host.virtualY;
        const right = left + host.width;
        const bottom = top + host.height;

        if (icon.width <= 0) {
            // The system would not say where the icon is; the lower right corner
            // is where it almost always is.
            root.x = right - root.width - margin;
            root.y = bottom - root.height - margin;
            return;
        }

        const iconCentreX = icon.x + icon.width / 2;
        const iconCentreY = icon.y + icon.height / 2;
        const verticalBar = icon.y > top + host.height * 0.2
            && icon.y < bottom - host.height * 0.2;

        if (verticalBar) {
            root.x = iconCentreX < (left + right) / 2
                ? icon.x + icon.width + margin
                : icon.x - root.width - margin;
            root.y = iconCentreY - root.height / 2;
        } else {
            root.x = iconCentreX - root.width / 2;
            root.y = iconCentreY < (top + bottom) / 2
                ? icon.y + icon.height + margin
                : icon.y - root.height - margin;
        }

        root.x = Math.max(left + margin, Math.min(root.x, right - root.width - margin));
        root.y = Math.max(top + margin, Math.min(root.y, bottom - root.height - margin));
    }

    // Clicking anywhere else is how a popover is dismissed - but only once it
    // has been in front itself.
    onActiveChanged: {
        if (active) {
            everActivated = true;
        } else if (everActivated && visible) {
            hide();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.hide()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(6 * Theme.scale)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Math.round(12 * Theme.scale)
            spacing: Math.round(10 * Theme.scale)

            // ------------------------------------------------------- the state
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Mascot {
                    mood: root.mood
                    size: Math.round(58 * Theme.scale)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: controller.currentProfile !== "" ? controller.currentProfile
                            : qsTr("Ocelot")
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLarge
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 5

                        PulseDot {
                            tint: Theme.statusColor(root.status)
                            active: Theme.statusIsBusy(root.status)
                            dotSize: Math.round(7 * Theme.scale)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: controller.reconnectPending ? qsTr("Dialling again shortly")
                                : Theme.statusLabel(root.status)
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: root.connected
                        text: controller.uptime
                        color: Theme.ok
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                    }
                }

                ColumnLayout {
                    spacing: 1

                    GhostButton {
                        glyph: "window"
                        onClicked: root.windowRequested("connection")
                        tip: qsTr("Open the Ocelot window")
                    }

                    GhostButton {
                        glyph: "gear"
                        onClicked: root.windowRequested("settings")
                        tip: qsTr("Settings")
                    }
                }
            }

            // --------------------------------------------------- what it got
            Card {
                Layout.fillWidth: true
                visible: root.connected
                padding: Math.round(11 * Theme.scale)
                columnSpacing: Math.round(8 * Theme.scale)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StatTile {
                        Layout.fillWidth: true
                        glyph: "arrowDown"
                        label: qsTr("Down")
                        value: Theme.formatRate(controller.rxRate)
                        detail: qsTr("%1 total").arg(controller.received)
                        tint: Theme.ok
                    }

                    StatTile {
                        Layout.fillWidth: true
                        glyph: "arrowUp"
                        label: qsTr("Up")
                        value: Theme.formatRate(controller.txRate)
                        detail: qsTr("%1 total").arg(controller.sent)
                        tint: Theme.busy
                    }
                }

                ThroughputChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(40 * Theme.scale)
                    rxSamples: Telemetry.rx
                    txSamples: Telemetry.tx
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.line
                }

                DetailRow {
                    Layout.fillWidth: true
                    label: qsTr("IP address")
                    value: controller.ip
                    mono: true
                }

                DetailRow {
                    Layout.fillWidth: true
                    label: qsTr("DNS")
                    value: controller.dns !== "" ? controller.dns : qsTr("none applied")
                    mono: controller.dns !== ""
                }
            }

            // ----------------------------------------------------- the action
            ChunkyButton {
                Layout.fillWidth: true

                enabled: controller.currentProfile !== "" || !root.connected
                busy: Theme.statusIsBusy(root.status)
                glyph: root.status === Theme.statusConnecting ? "close" : "power"
                tint: root.connected ? Theme.danger
                    : root.status === Theme.statusConnecting ? Theme.muted
                    : controller.profiles.length === 0 ? Theme.off
                    : Theme.accent
                text: root.connected ? qsTr("Disconnect")
                    : root.status === Theme.statusConnecting ? qsTr("Cancel")
                    : root.status === Theme.statusDisconnecting ? qsTr("Disconnecting")
                    : controller.profiles.length === 0 ? qsTr("Add your first profile")
                    : controller.currentProfile !== ""
                        ? qsTr("Connect to %1").arg(controller.currentProfile)
                        : qsTr("Connect")

                onClicked: {
                    if (controller.profiles.length === 0) {
                        root.newProfileRequested();
                        root.hide();
                    } else if (root.status === Theme.statusDisconnected) {
                        controller.connectVpn();
                    } else {
                        controller.disconnectVpn();
                    }
                }
            }

            // ---------------------------------------------------- the profiles
            ColumnLayout {
                Layout.fillWidth: true
                visible: controller.profiles.length > 0
                spacing: Math.round(5 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Profiles")
                    trailing: String(controller.profiles.length)
                }

                Repeater {
                    model: controller.profileEntries

                    delegate: ProfileRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true

                        name: modelData.name
                        emoji: modelData.emoji
                        subtitle: modelData.gateway.length > 0 ? modelData.gateway
                            : qsTr("No server set")
                        selected: controller.currentProfile === modelData.name
                        active: controller.currentProfile === modelData.name
                            && controller.status !== Theme.statusDisconnected
                        statusColor: Theme.statusColor(controller.status)
                        busy: Theme.statusIsBusy(controller.status)
                        shortcutHint: index < 9 ? "Ctrl+" + (index + 1) : ""
                        allowActions: false

                        // One click picks a profile and dials it: that is what
                        // someone came to the notification area to do.
                        onClicked: {
                            controller.currentProfile = modelData.name;
                            if (controller.status === Theme.statusDisconnected)
                                controller.connectToProfile(modelData.name);
                        }
                    }
                }
            }

            // ------------------------------------------------------ the footer
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4

                GhostButton {
                    glyph: "plus"
                    text: qsTr("Add profile")
                    onClicked: {
                        root.newProfileRequested();
                        root.hide();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                GhostButton {
                    glyph: "log"
                    onClicked: root.windowRequested("log")
                    tip: qsTr("Activity log")
                }

                GhostButton {
                    glyph: "info"
                    onClicked: root.windowRequested("about")
                    tip: qsTr("About Ocelot")
                }

                GhostButton {
                    glyph: "power"
                    tint: Theme.faint
                    onClicked: controller.quit()
                    tip: qsTr("Quit Ocelot")
                }
            }
        }
    }

    // The first nine profiles answer to Ctrl and their number while the popover
    // is open. An Instantiator rather than a Repeater, because a shortcut is not
    // something that can be laid out.
    Instantiator {
        model: Math.min(9, controller.profiles.length)

        delegate: Shortcut {
            required property int index

            sequence: "Ctrl+" + (index + 1)
            enabled: root.visible
            onActivated: {
                const name = controller.profiles[index];
                controller.currentProfile = name;
                if (controller.status === Theme.statusDisconnected)
                    controller.connectToProfile(name);
            }
        }
    }
}
