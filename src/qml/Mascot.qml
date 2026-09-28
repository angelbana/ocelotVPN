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

// The program's ocelot. Its face says what the connection is doing, which is
// how a person can tell at a glance without reading anything.
//
// Drawn rather than drawn-and-exported: at every size from the sidebar's 40
// pixels to the window's 104 the lines stay the same weight, and a theme change
// is a repaint rather than a new set of images.
//
// Deliberately still. An earlier version blinked, and a face that moves while
// nothing is happening reads as a fault rather than as charm.
Canvas {
    id: root

    // "sleepy" | "curious" | "happy" | "worried" | "asking"
    property string mood: "sleepy"
    // The tinted disc behind the face. On is right everywhere in the program,
    // where it carries the state colour; off is for the program's own icon,
    // which brings its own background.
    property bool halo: true
    property int size: Math.round(96 * Theme.scale)

    readonly property color moodTint: mood === "happy" ? Theme.ok
        : mood === "curious" ? Theme.busy
        : mood === "worried" ? Theme.danger
        : mood === "asking" ? Theme.accent
        : Theme.off

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    antialiasing: true

    onMoodChanged: requestPaint()
    onHaloChanged: requestPaint()
    onMoodTintChanged: requestPaint()

    // A theme change repaints everything; the pelt is the one that gives it away
    // if it does not.
    Connections {
        target: Theme
        function onModeChanged() { root.requestPaint(); }
    }

    onPaint: {
        const ctx = getContext("2d");
        const k = width / 100;
        ctx.reset();
        ctx.save();
        ctx.scale(k, k);

        if (halo)
            drawHalo(ctx);
        drawWhiskers(ctx);
        drawEar(ctx, -1);
        drawEar(ctx, 1);
        drawHead(ctx);
        drawMarkings(ctx);
        drawEye(ctx, -1);
        drawEye(ctx, 1);
        drawMuzzle(ctx);

        ctx.restore();
    }

    // The whole face sits in a tinted disc, which is what carries the state
    // colour at small sizes where the expression is too fine to read.
    function drawHalo(ctx) {
        ctx.beginPath();
        ctx.arc(50, 50, 49, 0, Math.PI * 2);
        ctx.fillStyle = Qt.alpha(moodTint, Theme.night ? 0.22 : 0.14);
        ctx.fill();
    }

    // An ocelot's head is not an oval: the jaw flares out below the eyes and
    // narrows to a small chin. Both halves come from the same numbers with the
    // sign flipped, so it cannot end up lopsided.
    function drawHead(ctx) {
        ctx.beginPath();
        ctx.moveTo(50, 23);
        ctx.bezierCurveTo(72, 23, 82, 34, 82, 48);
        ctx.bezierCurveTo(82, 58, 79, 66, 72, 73);
        ctx.bezierCurveTo(66, 78, 58, 80, 50, 80);
        ctx.bezierCurveTo(42, 80, 34, 78, 28, 73);
        ctx.bezierCurveTo(21, 66, 18, 58, 18, 48);
        ctx.bezierCurveTo(18, 34, 28, 23, 50, 23);
        ctx.closePath();

        const pelt = ctx.createLinearGradient(0, 20, 0, 82);
        pelt.addColorStop(0, Theme.pelt);
        pelt.addColorStop(1, Theme.peltShade);
        ctx.fillStyle = pelt;
        ctx.fill();
    }

    function drawEar(ctx, side) {
        const tilt = mood === "worried" ? 0.62 : mood === "curious" || mood === "asking" ? 0.12 : 0.26;

        ctx.save();
        // Rotated about where the ear meets the head, so it swings rather than
        // slides when the mood changes.
        ctx.translate(50 + side * 24, 32);
        ctx.rotate(side * tilt);

        ctx.beginPath();
        ctx.moveTo(side * -9, 6);
        ctx.bezierCurveTo(side * -7, -12, side * 2, -19, side * 8, -16);
        ctx.bezierCurveTo(side * 12, -10, side * 11, 0, side * 8, 7);
        ctx.closePath();
        ctx.fillStyle = Theme.peltShade;
        ctx.fill();

        ctx.beginPath();
        ctx.moveTo(side * -4, 4);
        ctx.bezierCurveTo(side * -3, -6, side * 1, -11, side * 5, -9);
        ctx.bezierCurveTo(side * 7, -5, side * 6, 0, side * 4, 4);
        ctx.closePath();
        ctx.fillStyle = Theme.blush;
        ctx.fill();

        ctx.restore();
    }

    // Streaks running back over the forehead and spots along the cheeks: the
    // markings an ocelot is recognised by, rather than spots scattered evenly.
    function drawMarkings(ctx) {
        ctx.strokeStyle = Qt.alpha(Theme.spot, 0.34);
        ctx.lineCap = "round";
        ctx.lineWidth = 2.6;

        for (const side of [-1, 1]) {
            ctx.beginPath();
            ctx.moveTo(50 + side * 4, 33);
            ctx.quadraticCurveTo(50 + side * 6, 27, 50 + side * 10, 25);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(50 + side * 11, 35);
            ctx.quadraticCurveTo(50 + side * 15, 30, 50 + side * 20, 28);
            ctx.stroke();
        }

        ctx.fillStyle = Qt.alpha(Theme.spot, 0.26);
        for (const side of [-1, 1]) {
            spot(ctx, 50 + side * 25, 46, 4.4, 3.2);
            spot(ctx, 50 + side * 27, 55, 3.4, 2.6);
            spot(ctx, 50 + side * 22, 63, 2.8, 2.2);
        }
    }

    function spot(ctx, x, y, rx, ry) {
        ctx.beginPath();
        ctx.ellipse(x - rx, y - ry, rx * 2, ry * 2);
        ctx.fill();
    }

    function drawEye(ctx, side) {
        const x = 50 + side * 12;
        const y = 50;
        const w = 6.2;

        ctx.strokeStyle = Theme.spot;
        ctx.fillStyle = Theme.spot;
        ctx.lineCap = "round";

        if (mood === "happy") {
            // A contented squint: two arcs, peaks up.
            ctx.lineWidth = 2.4;
            ctx.beginPath();
            ctx.moveTo(x - w * 0.8, y + 1.6);
            ctx.quadraticCurveTo(x, y - 4.4, x + w * 0.8, y + 1.6);
            ctx.stroke();
            return;
        }

        if (mood === "sleepy") {
            ctx.lineWidth = 2.2;
            ctx.beginPath();
            ctx.moveTo(x - w * 0.8, y);
            ctx.lineTo(x + w * 0.8, y);
            ctx.stroke();
            return;
        }

        // An open eye: white, a tall pupil, and one highlight so it does not
        // look painted on.
        ctx.beginPath();
        ctx.ellipse(x - w / 2, y - w * 0.62, w, w * 1.24);
        ctx.fillStyle = Theme.night ? "#f2efe9" : "#ffffff";
        ctx.fill();

        const pupil = mood === "worried" ? 0.42 : 0.54;
        ctx.beginPath();
        ctx.ellipse(x - w * pupil / 2, y - w * pupil * 0.78, w * pupil, w * pupil * 1.55);
        ctx.fillStyle = Theme.spot;
        ctx.fill();

        ctx.beginPath();
        ctx.arc(x + w * 0.14, y - w * 0.34, w * 0.13, 0, Math.PI * 2);
        ctx.fillStyle = Qt.alpha("#ffffff", 0.9);
        ctx.fill();

        if (mood === "worried") {
            // The inner end of the brow lifted, not lowered: lowered reads as
            // anger, and a connection that failed is not the user's fault.
            ctx.strokeStyle = Theme.spot;
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(x - side * 5, y - 8.6);
            ctx.lineTo(x + side * 5, y - 6.4);
            ctx.stroke();
        }
    }

    function drawMuzzle(ctx) {
        // Nose: a small rounded triangle, point down.
        ctx.beginPath();
        ctx.moveTo(46.4, 62);
        ctx.quadraticCurveTo(50, 60.6, 53.6, 62);
        ctx.quadraticCurveTo(52, 66.4, 50, 67);
        ctx.quadraticCurveTo(48, 66.4, 46.4, 62);
        ctx.closePath();
        ctx.fillStyle = Theme.blush;
        ctx.fill();

        ctx.strokeStyle = Qt.alpha(Theme.spot, 0.7);
        ctx.lineWidth = 2;
        ctx.lineCap = "round";

        if (mood === "happy" || mood === "asking") {
            ctx.beginPath();
            ctx.moveTo(44.6, 68.4);
            ctx.quadraticCurveTo(50, 74.2, 55.4, 68.4);
            ctx.stroke();
        } else if (mood === "worried") {
            ctx.beginPath();
            ctx.moveTo(45.6, 72);
            ctx.quadraticCurveTo(50, 68.2, 54.4, 72);
            ctx.stroke();
        } else {
            ctx.beginPath();
            ctx.moveTo(47.6, 69.4);
            ctx.lineTo(52.4, 69.4);
            ctx.stroke();
        }
    }

    // Behind the head, so they come out from under the cheeks.
    function drawWhiskers(ctx) {
        ctx.strokeStyle = Qt.alpha(Theme.spot, 0.38);
        ctx.lineWidth = 1.3;
        ctx.lineCap = "round";

        for (const side of [-1, 1]) {
            for (const tilt of [-4.5, 0, 4.5]) {
                ctx.beginPath();
                ctx.moveTo(50 + side * 20, 58 + tilt * 0.5);
                ctx.quadraticCurveTo(50 + side * 34, 58 + tilt * 1.1,
                                     50 + side * 46, 58 + tilt * 1.9);
                ctx.stroke();
            }
        }
    }
}
