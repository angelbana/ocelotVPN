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

// The program's icons, drawn rather than set in a font.
//
// An icon font would have been shorter, but there is no one font on both
// Windows and Linux that has these shapes, and a missing glyph draws as an
// empty box in the middle of a button. These are line drawings on a 24 by 24
// grid, all with the same stroke, so they sit together as one set.
Canvas {
    id: root

    property string name: ""
    property color color: Theme.ink
    property int size: Math.round(14 * Theme.scale)
    property real thickness: 1.9

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    antialiasing: true

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const k = width / 24;
        ctx.reset();
        ctx.save();
        ctx.scale(k, k);
        ctx.strokeStyle = root.color;
        ctx.fillStyle = root.color;
        ctx.lineWidth = root.thickness;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        switch (root.name) {
        case "power":
            ctx.beginPath();
            ctx.arc(12, 13, 7.5, -Math.PI * 0.35, Math.PI * 1.35, false);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12, 3);
            ctx.lineTo(12, 11);
            ctx.stroke();
            break;

        case "plus":
            ctx.beginPath();
            ctx.moveTo(12, 5);
            ctx.lineTo(12, 19);
            ctx.moveTo(5, 12);
            ctx.lineTo(19, 12);
            ctx.stroke();
            break;

        case "close":
            ctx.beginPath();
            ctx.moveTo(6, 6);
            ctx.lineTo(18, 18);
            ctx.moveTo(18, 6);
            ctx.lineTo(6, 18);
            ctx.stroke();
            break;

        case "check":
            ctx.beginPath();
            ctx.moveTo(5, 13);
            ctx.lineTo(10, 18);
            ctx.lineTo(19, 6);
            ctx.stroke();
            break;

        case "gear":
            // The teeth start at the rim rather than out in space, or the whole
            // thing reads as a sun instead of a cog.
            ctx.beginPath();
            ctx.arc(12, 12, 6.1, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 12, 2.6, 0, Math.PI * 2);
            ctx.stroke();
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4 + Math.PI / 8;
                ctx.beginPath();
                ctx.moveTo(12 + Math.cos(a) * 5.4, 12 + Math.sin(a) * 5.4);
                ctx.lineTo(12 + Math.cos(a) * 9, 12 + Math.sin(a) * 9);
                ctx.stroke();
            }
            break;

        case "log":
            ctx.beginPath();
            ctx.moveTo(4, 6.5); ctx.lineTo(20, 6.5);
            ctx.moveTo(4, 11.5); ctx.lineTo(17, 11.5);
            ctx.moveTo(4, 16.5); ctx.lineTo(19, 16.5);
            ctx.moveTo(4, 21); ctx.lineTo(13, 21);
            ctx.stroke();
            break;

        case "info":
            ctx.beginPath();
            ctx.arc(12, 12, 8.5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12, 11);
            ctx.lineTo(12, 17);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 7.6, 1.15, 0, Math.PI * 2);
            ctx.fill();
            break;

        case "question":
            ctx.beginPath();
            ctx.arc(12, 12, 8.5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 10, 2.8, Math.PI, Math.PI * 2.35, false);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12.6, 12.4);
            ctx.lineTo(12, 14.6);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 17.2, 1.1, 0, Math.PI * 2);
            ctx.fill();
            break;

        case "warning":
            ctx.beginPath();
            ctx.moveTo(12, 3.5);
            ctx.lineTo(21.5, 20);
            ctx.lineTo(2.5, 20);
            ctx.closePath();
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12, 9.5);
            ctx.lineTo(12, 14.5);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(12, 17.3, 1.1, 0, Math.PI * 2);
            ctx.fill();
            break;

        case "arrowDown":
            ctx.beginPath();
            ctx.moveTo(12, 4);
            ctx.lineTo(12, 19);
            ctx.moveTo(6, 13.5);
            ctx.lineTo(12, 19.5);
            ctx.lineTo(18, 13.5);
            ctx.stroke();
            break;

        case "arrowUp":
            ctx.beginPath();
            ctx.moveTo(12, 20);
            ctx.lineTo(12, 5);
            ctx.moveTo(6, 10.5);
            ctx.lineTo(12, 4.5);
            ctx.lineTo(18, 10.5);
            ctx.stroke();
            break;

        case "clock":
            ctx.beginPath();
            ctx.arc(12, 12, 8.5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(12, 7);
            ctx.lineTo(12, 12.5);
            ctx.lineTo(16, 14.5);
            ctx.stroke();
            break;

        case "bolt":
            ctx.beginPath();
            ctx.moveTo(13.5, 3);
            ctx.lineTo(6.5, 13.5);
            ctx.lineTo(11.5, 13.5);
            ctx.lineTo(10.5, 21);
            ctx.lineTo(17.5, 10.5);
            ctx.lineTo(12.5, 10.5);
            ctx.closePath();
            ctx.stroke();
            break;

        case "pencil":
            ctx.beginPath();
            ctx.moveTo(4.5, 19.5);
            ctx.lineTo(5.5, 15.5);
            ctx.lineTo(16, 5);
            ctx.lineTo(19, 8);
            ctx.lineTo(8.5, 18.5);
            ctx.closePath();
            ctx.stroke();
            break;

        case "trash":
            ctx.beginPath();
            ctx.moveTo(4.5, 7.5);
            ctx.lineTo(19.5, 7.5);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(9.5, 7.5);
            ctx.lineTo(9.5, 4.5);
            ctx.lineTo(14.5, 4.5);
            ctx.lineTo(14.5, 7.5);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(6.5, 7.5);
            ctx.lineTo(7.5, 20);
            ctx.lineTo(16.5, 20);
            ctx.lineTo(17.5, 7.5);
            ctx.stroke();
            break;

        case "window":
            ctx.beginPath();
            ctx.roundedRect(3.5, 5, 17, 14, 2.5, 2.5);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(3.5, 9.5);
            ctx.lineTo(20.5, 9.5);
            ctx.stroke();
            break;

        case "refresh":
            ctx.beginPath();
            ctx.arc(12, 12, 7.5, Math.PI * 0.6, Math.PI * 2.1, false);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(15.4, 3.4);
            ctx.lineTo(16.6, 8.2);
            ctx.lineTo(11.8, 8.4);
            ctx.stroke();
            break;

        case "copy":
            ctx.beginPath();
            ctx.roundedRect(8.5, 8.5, 11, 11.5, 2.2, 2.2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(15.5, 5.5);
            ctx.lineTo(6.5, 5.5);
            ctx.lineTo(5.5, 6.5);
            ctx.lineTo(5.5, 15);
            ctx.stroke();
            break;

        case "chevronRight":
            ctx.beginPath();
            ctx.moveTo(9.5, 5.5);
            ctx.lineTo(16, 12);
            ctx.lineTo(9.5, 18.5);
            ctx.stroke();
            break;

        case "chevronLeft":
            ctx.beginPath();
            ctx.moveTo(14.5, 5.5);
            ctx.lineTo(8, 12);
            ctx.lineTo(14.5, 18.5);
            ctx.stroke();
            break;

        case "shield":
            ctx.beginPath();
            ctx.moveTo(12, 3.5);
            ctx.lineTo(19.5, 6.5);
            ctx.lineTo(19.5, 12);
            ctx.bezierCurveTo(19.5, 16.5, 16, 19.5, 12, 20.5);
            ctx.bezierCurveTo(8, 19.5, 4.5, 16.5, 4.5, 12);
            ctx.lineTo(4.5, 6.5);
            ctx.closePath();
            ctx.stroke();
            break;

        case "globe":
            ctx.beginPath();
            ctx.arc(12, 12, 8.5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(3.5, 12);
            ctx.lineTo(20.5, 12);
            ctx.stroke();
            ctx.beginPath();
            ctx.ellipse(7.5, 3.5, 9, 17);
            ctx.stroke();
            break;
        }

        ctx.restore();
    }
}
