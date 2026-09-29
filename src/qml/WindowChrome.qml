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

// The top of the window, drawn by the program rather than by the system.
//
// Three round buttons at the left and the name in the middle, the way the Mac
// client has them, so the two programs are recognisably one family. The window
// is frameless, so this bar is also what it is dragged by.
//
// The marks inside the buttons only appear under the pointer. That is the point
// of them: at rest the colours are enough, and three glyphs sitting there all
// the time would be three more things to look at.
Rectangle {
    id: root

    required property Window window
    property string title: ""

    implicitHeight: Math.round(38 * Theme.scale)
    color: Theme.night ? Qt.lighter(Theme.surface, 1.25) : Theme.card

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.line
    }

    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onTapped: {
            if (tapCount === 2)
                root.toggleMaximized();
        }
        onPressedChanged: {
            if (pressed)
                root.window.startSystemMove();
        }
    }

    function toggleMaximized() {
        if (root.window.visibility === Window.Maximized)
            root.window.showNormal();
        else
            root.window.showMaximized();
    }

    // The title sits in the middle of the window, not in the middle of what is
    // left over beside the buttons.
    Text {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - Math.round(220 * Theme.scale))
        text: root.title
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    Row {
        id: lights

        property bool showMarks: lightsHover.hovered

        anchors.left: parent.left
        anchors.leftMargin: Math.round(13 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(8 * Theme.scale)

        HoverHandler {
            id: lightsHover
        }

        component Light: AbstractButton {
            id: light

            property color tint: "#ff5f57"
            property string mark: ""

            implicitWidth: Math.round(13 * Theme.scale)
            implicitHeight: implicitWidth
            hoverEnabled: true

            background: Rectangle {
                radius: width / 2
                color: light.enabled ? (light.down ? Qt.darker(light.tint, 1.25) : light.tint)
                    : Theme.lineStrong
                border.width: 1
                border.color: Qt.darker(color, 1.12)
            }

            contentItem: Canvas {
                opacity: lights.showMarks && light.enabled ? 1 : 0
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    const k = width / 13;
                    ctx.reset();
                    ctx.save();
                    ctx.scale(k, k);
                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.55);
                    ctx.fillStyle = ctx.strokeStyle;
                    ctx.lineWidth = 1.3;
                    ctx.lineCap = "round";

                    switch (light.mark) {
                    case "close":
                        ctx.beginPath();
                        ctx.moveTo(4, 4);
                        ctx.lineTo(9, 9);
                        ctx.moveTo(9, 4);
                        ctx.lineTo(4, 9);
                        ctx.stroke();
                        break;

                    case "minimize":
                        ctx.beginPath();
                        ctx.moveTo(3.4, 6.5);
                        ctx.lineTo(9.6, 6.5);
                        ctx.stroke();
                        break;

                    case "zoom":
                        // Two facing corners, which is what this button does:
                        // fill the screen, or give the window back its size.
                        ctx.beginPath();
                        ctx.moveTo(3.6, 8.2);
                        ctx.lineTo(3.6, 4.4);
                        ctx.lineTo(7.4, 4.4);
                        ctx.moveTo(9.4, 4.8);
                        ctx.lineTo(9.4, 8.6);
                        ctx.lineTo(5.6, 8.6);
                        ctx.stroke();
                        break;
                    }

                    ctx.restore();
                }
            }
        }

        Light {
            tint: "#ff5f57"
            mark: "close"
            onClicked: root.window.close()
        }

        Light {
            tint: "#febc2e"
            mark: "minimize"
            onClicked: root.window.showMinimized()
        }

        Light {
            tint: "#28c840"
            mark: "zoom"
            onClicked: root.toggleMaximized()
        }
    }
}
