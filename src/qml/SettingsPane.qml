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

Item {
    id: root

    signal updatesRequested()

    readonly property bool onWindows: Qt.platform.os === "windows"

    // A row of a card: a name, a sentence saying what it does, and the control.
    component SettingRow: RowLayout {
        id: settingRow

        property string label: ""
        property string hint: ""
        default property alias trailing: holder.data

        Layout.fillWidth: true
        spacing: Math.round(16 * Theme.scale)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: settingRow.label
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: settingRow.hint.length > 0
                text: settingRow.hint
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: holder

            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.line
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: root.width
            spacing: Math.round(13 * Theme.scale)

            Text {
                Layout.leftMargin: Theme.padding
                Layout.topMargin: Theme.padding
                text: qsTr("Settings")
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.weight: Font.Bold
            }

            // ------------------------------------------------ connecting itself
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                padding: Math.round(14 * Theme.scale)
                columnSpacing: Math.round(11 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Connecting without being asked")
                }

                SettingRow {
                    label: qsTr("Which profile")
                    hint: qsTr("The one the two settings below dial.")

                    AppComboBox {
                        implicitWidth: Math.round(200 * Theme.scale)
                        model: [qsTr("Nothing")].concat(controller.profiles)
                        currentIndex: Math.max(0, controller.profiles.indexOf(controller.autoConnectProfile) + 1)
                        onActivated: index => controller.autoConnectProfile = index === 0
                            ? "" : controller.profiles[index - 1]
                    }
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Connect when Ocelot starts")
                    description: qsTr("Dials as soon as the window is up, however it was started.")
                    checked: controller.connectOnStart
                    enabled: controller.autoConnectProfile !== ""
                    onSwitched: checked => controller.connectOnStart = checked
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Connect when I sign in to Windows")
                    description: qsTr("Turning this on also has Ocelot start at sign-in, since it "
                        + "cannot dial before it is running.")
                    checked: controller.connectOnLogon
                    enabled: root.onWindows && controller.autoConnectProfile !== ""
                    visible: root.onWindows
                    onSwitched: checked => controller.connectOnLogon = checked
                }

                Separator {
                    visible: root.onWindows
                }

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Dial again if the connection drops")
                    description: qsTr("Only after a connection that was up and was not ended by you. "
                        + "The waits grow: 5 seconds, then 10, 20, 30, a minute, and then it stops.")
                    checked: controller.reconnectOnDrop
                    onSwitched: checked => controller.reconnectOnDrop = checked
                }
            }

            // ------------------------------------------------------ the program
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                padding: Math.round(14 * Theme.scale)
                columnSpacing: Math.round(11 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("The program")
                }

                AppToggle {
                    Layout.fillWidth: true
                    visible: controller.autostartSupported
                    text: qsTr("Start Ocelot when I sign in")
                    description: qsTr("Registered as a scheduled task, which is what lets it start "
                        + "with the privileges it needs without asking every time.")
                    checked: controller.autostart
                    onSwitched: checked => controller.autostart = checked
                }

                Separator {
                    visible: controller.autostartSupported
                }

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Start out of the way")
                    description: qsTr("Open straight to the notification area instead of showing "
                        + "the window.")
                    checked: controller.startMinimized
                    onSwitched: checked => controller.startMinimized = checked
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Keep running in the notification area")
                    description: qsTr("Minimizing puts Ocelot in the tray rather than the taskbar.")
                    checked: controller.minimizeToTray
                    enabled: controller.hasTray
                    onSwitched: checked => controller.minimizeToTray = checked
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Closing the window leaves Ocelot running")
                    description: qsTr("Quit from the tray menu. A connection survives a closed "
                        + "window; it does not survive quitting.")
                    checked: controller.minimizeInsteadOfClose
                    enabled: controller.hasTray
                    onSwitched: checked => controller.minimizeInsteadOfClose = checked
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Say when the tunnel comes up or goes down")
                    description: qsTr("A short message from the notification area, and nothing "
                        + "while the connection just sits there working.")
                    checked: controller.notifyOnChange
                    enabled: controller.hasTray
                    onSwitched: checked => controller.notifyOnChange = checked
                }

                Separator {}

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("One Ocelot at a time")
                    description: qsTr("Starting it again brings this window forward instead of "
                        + "opening a second one.")
                    checked: controller.singleInstance
                    onSwitched: checked => controller.singleInstance = checked
                }
            }

            // -------------------------------------------------------- the looks
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                padding: Math.round(14 * Theme.scale)
                columnSpacing: Math.round(11 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Appearance")
                }

                SettingRow {
                    label: qsTr("Language")
                    hint: qsTr("Takes effect straight away.")

                    AppComboBox {
                        implicitWidth: Math.round(200 * Theme.scale)
                        textRole: "label"
                        valueRole: "value"
                        model: controller.languages()
                        selectedValue: controller.language
                        onActivated: controller.language = currentValue
                    }
                }

                Separator {}

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Three looks with the same layout: only the colours change.")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: Math.round(10 * Theme.scale)

                    Repeater {
                        model: [
                            { "mode": Theme.themeOcelot, "name": qsTr("Ocelot"), "hint": qsTr("warm paper") },
                            { "mode": Theme.themeDay, "name": qsTr("Day"), "hint": qsTr("cool and light") },
                            { "mode": Theme.themeNight, "name": qsTr("Night"), "hint": qsTr("dark") }
                        ]

                        // A swatch of the theme it offers, so the choice is made
                        // by looking rather than by reading.
                        delegate: AbstractButton {
                            id: swatch

                            required property var modelData

                            readonly property bool active: controller.theme === modelData.mode
                            readonly property var colors: Theme.palettes[modelData.mode]

                            Layout.fillWidth: true
                            implicitHeight: Math.round(74 * Theme.scale)
                            onClicked: controller.theme = modelData.mode

                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: swatch.colors.surface
                                border.width: swatch.active ? 2 : 1
                                border.color: swatch.active ? Theme.accent : Theme.line
                            }

                            contentItem: ColumnLayout {
                                spacing: 5

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 2
                                    spacing: 4

                                    Repeater {
                                        model: [swatch.colors.accent, swatch.colors.mint,
                                            swatch.colors.card, swatch.colors.ink]

                                        delegate: Rectangle {
                                            required property color modelData

                                            width: Math.round(14 * Theme.scale)
                                            height: width
                                            radius: width / 2
                                            color: modelData
                                            border.width: 1
                                            border.color: swatch.colors.stroke
                                        }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: swatch.modelData.name
                                    color: swatch.colors.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                    font.weight: swatch.active ? Font.DemiBold : Font.Normal
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: swatch.modelData.hint
                                    color: swatch.colors.inkFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------- the rest
            Card {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                padding: Math.round(14 * Theme.scale)
                columnSpacing: Math.round(11 * Theme.scale)

                SectionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Maintenance")
                }

                AppToggle {
                    Layout.fillWidth: true
                    text: qsTr("Look for new versions")
                    description: qsTr("Asks GitHub every few days whether a newer release exists. "
                        + "Nothing is downloaded or installed without you.")
                    checked: controller.checkUpdates
                    onSwitched: checked => controller.checkUpdates = checked
                }

                Separator {}

                SettingRow {
                    label: qsTr("Updates")
                    hint: controller.checkingForUpdates
                        ? qsTr("Checking…")
                        : controller.latestVersion.length === 0
                            ? qsTr("Version %1 is installed.").arg(controller.appVersion)
                            : controller.updateAvailable
                                ? qsTr("Version %1 is out; you have %2.")
                                    .arg(controller.latestVersion).arg(controller.releaseVersion)
                                : qsTr("Version %1 is installed, which is the latest.")
                                    .arg(controller.appVersion)

                    GhostButton {
                        glyph: controller.updateAvailable ? "arrowDown" : "refresh"
                        text: controller.updateAvailable ? qsTr("Download") : qsTr("Check now")
                        enabled: !controller.checkingForUpdates
                        onClicked: {
                            if (controller.updateAvailable)
                                Qt.openUrlExternally(controller.downloadUrl());
                            else
                                root.updatesRequested();
                        }
                    }
                }

                Separator {
                    visible: root.onWindows
                }

                // Split DNS is programmed through the name resolution policy
                // table, which only Windows has; there is nothing to repair
                // anywhere else.
                SettingRow {
                    visible: root.onWindows
                    label: qsTr("Split DNS")
                    hint: qsTr("A connection that ended abruptly can leave its rules behind, and "
                        + "the names they cover stop resolving.")

                    GhostButton {
                        glyph: "shield"
                        text: qsTr("Repair")
                        onClicked: controller.repairDns()
                    }
                }

                Separator {}

                SettingRow {
                    label: qsTr("Log level")
                    hint: qsTr("Profiles set to the program default use this. Debug and trace "
                        + "carry protocol details, so share those with care.")

                    AppComboBox {
                        implicitWidth: Math.round(200 * Theme.scale)
                        textRole: "label"
                        valueRole: "value"
                        model: controller.logLevels()
                        selectedValue: controller.logLevel
                        onActivated: controller.logLevel = currentValue
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.padding
            }
        }
    }
}
