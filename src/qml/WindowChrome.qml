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

// The top of the window, drawn by the program rather than by the system.
//
// The window is frameless, so this bar is also what a person drags it by, and
// the three buttons at its right are the ones the system would otherwise draw.
// They keep the arrangement Windows uses - minimize, maximize, close, in that
// order, at that end - because a window that puts them somewhere else is a
// window people close by accident.
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

    // Dragging anywhere in the bar moves the window; the system does the work,
    // so it snaps to the edges of the screen as any other window does.
    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onTapped: (eventPoint, button) => {
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(12 * Theme.scale)
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        // The three system buttons. Square and flush to the top right, the way
        // every other window on this desktop has them.
        Row {
            Layout.fillHeight: true
            spacing: 0

            component ChromeButton: AbstractButton {
                id: chrome

                property string mark: ""
                property bool closes: false

                width: Math.round(46 * Theme.scale)
                height: root.height
                hoverEnabled: true

                background: Rectangle {
                    color: chrome.closes
                        ? (chrome.hovered ? "#d8453a" : "transparent")
                        : (chrome.hovered ? Theme.cardHover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }
                }

                contentItem: Item {
                    Canvas {
                        anchors.centerIn: parent
                        width: Math.round(11 * Theme.scale)
                        height: width
                        antialiasing: true

                        property color ink: chrome.closes && chrome.hovered
                            ? "#ffffff" : Theme.muted

                        onInkChanged: requestPaint()

                        Connections {
                            target: Theme
                            function onModeChanged() { parent.children[0].requestPaint(); }
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const k = width / 11;
                            ctx.reset();
                            ctx.save();
                            ctx.scale(k, k);
                            ctx.strokeStyle = ink;
                            ctx.lineWidth = 1.2;
                            ctx.lineCap = "round";

                            switch (chrome.mark) {
                            case "minimize":
                                ctx.beginPath();
                                ctx.moveTo(0.5, 5.5);
                                ctx.lineTo(10.5, 5.5);
                                ctx.stroke();
                                break;

                            case "maximize":
                                if (root.window.visibility === Window.Maximized) {
                                    // Two sheets, for the window that would come
                                    // back to its old size.
                                    ctx.strokeRect(0.5, 2.5, 8, 8);
                                    ctx.beginPath();
                                    ctx.moveTo(2.5, 2.5);
                                    ctx.lineTo(2.5, 0.5);
                                    ctx.lineTo(10.5, 0.5);
                                    ctx.lineTo(10.5, 8.5);
                                    ctx.lineTo(8.5, 8.5);
                                    ctx.stroke();
                                } else {
                                    ctx.strokeRect(0.5, 0.5, 10, 10);
                                }
                                break;

                            case "close":
                                ctx.beginPath();
                                ctx.moveTo(0.8, 0.8);
                                ctx.lineTo(10.2, 10.2);
                                ctx.moveTo(10.2, 0.8);
                                ctx.lineTo(0.8, 10.2);
                                ctx.stroke();
                                break;
                            }

                            ctx.restore();
                        }
                    }
                }
            }

            ChromeButton {
                mark: "minimize"
                onClicked: root.window.showMinimized()
            }

            ChromeButton {
                mark: "maximize"
                onClicked: root.toggleMaximized()
            }

            ChromeButton {
                mark: "close"
                closes: true
                onClicked: root.window.close()
            }
        }
    }
}
