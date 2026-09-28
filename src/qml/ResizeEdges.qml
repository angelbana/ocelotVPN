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

// The band around a frameless window that it can be resized by.
//
// A window without a frame has nothing for the pointer to catch, so these eight
// invisible strips stand in for it. The system does the resizing itself, which
// is what keeps it smooth and what makes the edges snap.
Item {
    id: root

    required property Window window

    readonly property int grip: Math.round(6 * Theme.scale)
    readonly property bool enabledNow: window.visibility === Window.Windowed

    anchors.fill: parent

    component Edge: Item {
        id: edge

        required property int edges
        required property int cursor

        visible: root.enabledNow

        HoverHandler {
            cursorShape: edge.cursor
        }

        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: {
                if (pressed)
                    root.window.startSystemResize(edge.edges);
            }
        }
    }

    Edge {
        edges: Qt.LeftEdge
        cursor: Qt.SizeHorCursor
        x: 0
        y: root.grip
        width: root.grip
        height: root.height - root.grip * 2
    }

    Edge {
        edges: Qt.RightEdge
        cursor: Qt.SizeHorCursor
        x: root.width - root.grip
        y: root.grip
        width: root.grip
        height: root.height - root.grip * 2
    }

    Edge {
        edges: Qt.TopEdge
        cursor: Qt.SizeVerCursor
        x: root.grip
        y: 0
        width: root.width - root.grip * 2
        height: root.grip
    }

    Edge {
        edges: Qt.BottomEdge
        cursor: Qt.SizeVerCursor
        x: root.grip
        y: root.height - root.grip
        width: root.width - root.grip * 2
        height: root.grip
    }

    Edge {
        edges: Qt.LeftEdge | Qt.TopEdge
        cursor: Qt.SizeFDiagCursor
        x: 0
        y: 0
        width: root.grip
        height: root.grip
    }

    Edge {
        edges: Qt.RightEdge | Qt.TopEdge
        cursor: Qt.SizeBDiagCursor
        x: root.width - root.grip
        y: 0
        width: root.grip
        height: root.grip
    }

    Edge {
        edges: Qt.LeftEdge | Qt.BottomEdge
        cursor: Qt.SizeBDiagCursor
        x: 0
        y: root.height - root.grip
        width: root.grip
        height: root.grip
    }

    Edge {
        edges: Qt.RightEdge | Qt.BottomEdge
        cursor: Qt.SizeFDiagCursor
        x: root.width - root.grip
        y: root.height - root.grip
        width: root.grip
        height: root.grip
    }
}
