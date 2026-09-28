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

ApplicationWindow {
    id: mainWindow

    // "connection" | "log" | "settings" | "about"
    property string tab: "connection"
    property bool updateCheckPending: false

    // What the ocelot's face is doing. Everything that draws it - the window,
    // the popover, the About screen - reads this one value, so they cannot
    // disagree about what is going on.
    readonly property string mascotMood: prompt.opened ? "asking"
        : controller.status === Theme.statusConnected ? "happy"
        : controller.status === Theme.statusConnecting ? "curious"
        : controller.reconnectPending ? "worried"
        : "sleepy"

    // Against this screen, not against the whole desktop. Screen.width is the
    // screen the window is on; Screen.desktopAvailableWidth is every screen
    // added together, and using that here puts the window off the side of the
    // monitor the moment a second one is plugged in.
    width: Math.min(Theme.defaultWindowWidth, Screen.width)
    height: Math.min(Theme.defaultWindowHeight, Screen.height)
    minimumWidth: Math.min(Theme.minWindowWidth, Screen.width)
    minimumHeight: Math.min(Theme.minWindowHeight, Screen.height)
    visible: true
    color: Theme.surface
    title: Qt.application.displayName

    Component.onCompleted: {
        const saved = controller.windowGeometry();
        if (saved.width > 0 && saved.height > 0) {
            // A saved size can come from another screen: keep it inside the
            // current one, and never below the size at which the layout stops
            // being readable.
            mainWindow.width = Math.max(mainWindow.minimumWidth,
                Math.min(saved.width, Screen.width));
            mainWindow.height = Math.max(mainWindow.minimumHeight,
                Math.min(saved.height, Screen.height));
            mainWindow.x = Math.max(Screen.virtualX,
                Math.min(saved.x, Screen.virtualX + Screen.width - mainWindow.width));
            mainWindow.y = Math.max(Screen.virtualY,
                Math.min(saved.y, Screen.virtualY + Screen.height - mainWindow.height));
        } else {
            // Nothing remembered yet: a window the shape of what it holds, in
            // the middle of the screen it opened on rather than wherever the
            // system happened to drop it. A little above centre, because a
            // window sitting dead centre looks low.
            mainWindow.x = Screen.virtualX
                + Math.round((Screen.width - mainWindow.width) / 2);
            mainWindow.y = Screen.virtualY
                + Math.round((Screen.height - mainWindow.height) / 2.6);
        }
        if (controller.startMinimized) {
            if (controller.hasTray && controller.minimizeToTray)
                mainWindow.hide();
            else
                mainWindow.showMinimized();
        }
    }

    onClosing: function(close) {
        controller.saveWindowGeometry(Qt.rect(mainWindow.x, mainWindow.y,
            mainWindow.width, mainWindow.height));
        close.accepted = controller.requestWindowClose();
    }

    Binding {
        target: Theme
        property: "mode"
        value: controller.theme
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: mainWindow.tab = "log"
    }

    Shortcut {
        sequence: StandardKey.Preferences
        onActivated: mainWindow.tab = "settings"
    }

    Connections {
        target: controller

        function onWindowRequested(activate) {
            popover.hide();
            mainWindow.show();
            mainWindow.raise();
            if (activate)
                mainWindow.requestActivate();
        }

        function onWindowHideRequested() {
            mainWindow.hide();
        }

        function onWindowMinimizeRequested() {
            mainWindow.showMinimized();
        }

        function onErrorOccurred(title, message) {
            messageDialog.show(title, message);
        }

        function onPromptRequested(type, request) {
            // A question needs somewhere to be answered: the popover closes as
            // soon as anything else is clicked, so the window takes over.
            popover.hide();
            mainWindow.show();
            mainWindow.raise();
            mainWindow.requestActivate();
            prompt.ask(type, request);
        }

        function onPopoverToggleRequested() {
            popover.toggle();
        }

        // The chart's history is collected here, because this is the one thing
        // that exists for as long as the program does.
        function onStatsChanged() {
            Telemetry.push(controller.rxRate, controller.txRate);
        }

        function onStatusChanged() {
            if (controller.status === Theme.statusDisconnected)
                Telemetry.clear();
        }

        function onLatestVersionChanged() {
            if (!mainWindow.updateCheckPending)
                return;
            mainWindow.updateCheckPending = false;

            const latest = controller.latestVersion;
            if (latest.length === 0)
                messageDialog.show(qsTr("Check for updates"),
                    qsTr("The latest version could not be determined."));
            else if (!controller.updateAvailable)
                messageDialog.show(qsTr("Check for updates"),
                    qsTr("You are up to date. The latest version is %1.").arg(latest));
            else
                messageDialog.show(qsTr("Check for updates"),
                    qsTr("Version %1 is available, you have %2.<br><a href=\"%3\">Download it here</a>.")
                        .arg(latest).arg(controller.releaseVersion).arg(controller.downloadUrl()));
        }
    }

    // ------------------------------------------------------------------ layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- the sidebar
        Rectangle {
            Layout.preferredWidth: Theme.sidebarWidth
            Layout.fillHeight: true
            color: Theme.night ? Qt.lighter(Theme.surface, 1.25) : Theme.card

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.line
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // the program, and what it is doing right now
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(12 * Theme.scale)
                    Layout.rightMargin: Math.round(10 * Theme.scale)
                    Layout.topMargin: Math.round(10 * Theme.scale)
                    Layout.bottomMargin: Math.round(12 * Theme.scale)
                    spacing: 9

                    Mascot {
                        mood: mainWindow.mascotMood
                        size: Math.round(42 * Theme.scale)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: qsTr("Ocelot")
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMedium
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Theme.statusLabel(controller.status)
                            color: Theme.statusColor(controller.status)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }

                // the profiles
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: Theme.sidebarWidth
                        spacing: Math.round(4 * Theme.scale)

                        SectionLabel {
                            Layout.fillWidth: true
                            Layout.leftMargin: Math.round(12 * Theme.scale)
                            Layout.rightMargin: Math.round(12 * Theme.scale)
                            text: qsTr("Profiles")
                            trailing: controller.profiles.length > 0
                                ? String(controller.profiles.length) : ""
                        }

                        Repeater {
                            model: controller.profileEntries

                            delegate: ProfileRow {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.leftMargin: Math.round(8 * Theme.scale)
                                Layout.rightMargin: Math.round(8 * Theme.scale)

                                name: modelData.name
                                emoji: modelData.emoji
                                subtitle: modelData.gateway
                                selected: controller.currentProfile === modelData.name
                                active: controller.currentProfile === modelData.name
                                    && controller.status !== Theme.statusDisconnected
                                statusColor: Theme.statusColor(controller.status)
                                busy: Theme.statusIsBusy(controller.status)

                                lastConnected: Theme.formatWhen(modelData.lastConnected)

                                onClicked: {
                                    controller.currentProfile = modelData.name;
                                    mainWindow.tab = "connection";
                                }
                                onEditRequested: profileEditor.edit(modelData.name)
                                onRemoveRequested: removeDialog.ask(modelData.name)
                                onDuplicateRequested: controller.duplicateProfile(modelData.name)
                            }
                        }

                        GhostButton {
                            Layout.fillWidth: true
                            Layout.leftMargin: Math.round(10 * Theme.scale)
                            Layout.rightMargin: Math.round(10 * Theme.scale)
                            Layout.topMargin: 2
                            glyph: "plus"
                            text: qsTr("New profile")
                            tint: Theme.accent
                            onClicked: newProfile.open()
                        }

                        Item {
                            Layout.preferredHeight: Math.round(6 * Theme.scale)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.line
                }

                // the other screens
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Math.round(6 * Theme.scale)
                    spacing: 2

                    Repeater {
                        model: [
                            { "id": "log", "glyph": "log", "name": qsTr("Activity log") },
                            { "id": "settings", "glyph": "gear", "name": qsTr("Settings") },
                            { "id": "about", "glyph": "info", "name": qsTr("About") }
                        ]

                        delegate: GhostButton {
                            required property var modelData

                            Layout.fillWidth: true
                            glyph: modelData.glyph
                            text: modelData.name
                            selected: mainWindow.tab === modelData.id
                            onClicked: mainWindow.tab = mainWindow.tab === modelData.id
                                ? "connection" : modelData.id
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------------- the detail
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ConnectionPane {
                anchors.fill: parent
                visible: mainWindow.tab === "connection"
                onLogRequested: mainWindow.tab = "log"
                onEditRequested: profileEditor.edit(controller.currentProfile)
                onNewProfileRequested: newProfile.open()
            }

            LogPane {
                anchors.fill: parent
                visible: mainWindow.tab === "log"
            }

            SettingsPane {
                anchors.fill: parent
                visible: mainWindow.tab === "settings"
                onUpdatesRequested: {
                    mainWindow.updateCheckPending = true;
                    controller.checkForUpdates();
                }
            }

            AboutPane {
                anchors.fill: parent
                visible: mainWindow.tab === "about"
                onLicenseRequested: messageDialog.show(qsTr("License"), controller.licenseText())
            }
        }
    }

    // ----------------------------------------------------------- the popover
    TrayPopover {
        id: popover

        mood: mainWindow.mascotMood
        onWindowRequested: tab => {
            if (tab.length > 0)
                mainWindow.tab = tab;
            controller.showWindow();
        }
        onNewProfileRequested: {
            controller.showWindow();
            newProfile.open();
        }
    }

    // ------------------------------------------------------------- the sheets
    NewProfileSheet {
        id: newProfile
        onCustomizeRequested: name => profileEditor.edit(name)
    }

    ProfileEditor {
        id: profileEditor
        onRemoveRequested: name => removeDialog.ask(name)
    }

    PromptSheet {
        id: prompt
    }

    AppDialog {
        id: messageDialog
    }

    AppDialog {
        id: removeDialog

        property string profileName: ""

        acceptText: qsTr("Remove")
        destructive: true

        function ask(name) {
            removeDialog.profileName = name;
            removeDialog.show(qsTr("Remove this profile?"),
                qsTr("The profile '%1' and the password saved with it are deleted from this computer.")
                    .arg(name));
        }

        onAccepted: if (removeDialog.profileName.length > 0)
            controller.removeProfile(removeDialog.profileName)
    }
}
