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

// What came down above the line, what went up below it.
//
// Overlaying the two curves in one band looked better and made it impossible to
// tell which was which. Both halves share one scale, so a busy download next to
// a quiet upload reads as exactly that.
Canvas {
    id: root

    property var rxSamples: []
    property var txSamples: []

    implicitHeight: Math.round(64 * Theme.scale)
    antialiasing: true

    onRxSamplesChanged: requestPaint()
    onTxSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Theme
        function onModeChanged() { root.requestPaint(); }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const half = (height - 1) / 2;
        const peak = Math.max(1024, maximum(rxSamples), maximum(txSamples));

        // The mid line is drawn whether there is data or not, so an idle tunnel
        // shows an empty chart rather than an empty space.
        ctx.strokeStyle = Theme.line;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, Math.round(half) + 0.5);
        ctx.lineTo(width, Math.round(half) + 0.5);
        ctx.stroke();

        band(ctx, rxSamples, peak, 0, half, false, Theme.ok);
        band(ctx, txSamples, peak, half + 1, half, true, Theme.busy);
    }

    function maximum(samples) {
        let m = 0;
        for (let i = 0; i < samples.length; i++) {
            if (samples[i] > m)
                m = samples[i];
        }
        return m;
    }

    function band(ctx, samples, peak, top, bandHeight, flipped, tint) {
        if (samples.length < 2 || bandHeight <= 0)
            return;

        const step = width / Math.max(1, samples.length - 1);
        const baseline = flipped ? top : top + bandHeight;
        const point = function (index) {
            const value = Math.min(1, samples[index] / peak);
            const offset = value * (bandHeight - 1);
            return {
                "x": index * step,
                "y": flipped ? top + offset : top + bandHeight - offset
            };
        };

        ctx.beginPath();
        ctx.moveTo(0, baseline);
        for (let i = 0; i < samples.length; i++) {
            const p = point(i);
            ctx.lineTo(p.x, p.y);
        }
        ctx.lineTo((samples.length - 1) * step, baseline);
        ctx.closePath();

        const fill = ctx.createLinearGradient(0, flipped ? top + bandHeight : top,
                                              0, flipped ? top : top + bandHeight);
        fill.addColorStop(0, Qt.alpha(tint, 0.02));
        fill.addColorStop(1, Qt.alpha(tint, 0.3));
        ctx.fillStyle = fill;
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < samples.length; i++) {
            const p = point(i);
            if (i === 0)
                ctx.moveTo(p.x, p.y);
            else
                ctx.lineTo(p.x, p.y);
        }
        ctx.strokeStyle = tint;
        ctx.lineWidth = 1.6;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
    }
}
