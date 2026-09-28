import QtQuick

// The two marks for the notification area, drawn rather than borrowed.
//
// At sixteen pixels a face is mush, so this is the ocelot in silhouette: the
// head and the ears, and nothing else. The colour carries the state, which is
// the one thing a person reads from a tray icon without looking at it.
//
// Run it from the project root:
//   qml contrib/icons/tray-icon.qml
// and it writes the two PNGs into src/images.
Window {
    id: win

    property var marks: [
        { "name": "network-connected", "colour": "#1c9c7e" },
        { "name": "network-disconnected", "colour": "#7d8590" }
    ]
    property int index: 0

    visible: true
    width: 128
    height: 128
    color: "#00000000"

    Canvas {
        id: art

        property color tint: win.marks[win.index].colour

        width: 128
        height: 128
        antialiasing: true

        onTintChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const k = width / 100;
            ctx.reset();
            ctx.save();
            ctx.scale(k, k);
            ctx.fillStyle = art.tint;

            // Ears first, so the head covers where they meet it.
            for (const side of [-1, 1]) {
                ctx.beginPath();
                ctx.moveTo(50 + side * 12, 30);
                ctx.lineTo(50 + side * 34, 8);
                ctx.lineTo(50 + side * 36, 42);
                ctx.closePath();
                ctx.fill();
            }

            // The head: wide cheeks, small chin.
            ctx.beginPath();
            ctx.moveTo(50, 22);
            ctx.bezierCurveTo(74, 22, 86, 36, 86, 52);
            ctx.bezierCurveTo(86, 70, 72, 88, 50, 88);
            ctx.bezierCurveTo(28, 88, 14, 70, 14, 52);
            ctx.bezierCurveTo(14, 36, 26, 22, 50, 22);
            ctx.closePath();
            ctx.fill();

            // Eyes and nose punched back out, so the shape still reads as a
            // face when it is the size of a full stop.
            ctx.globalCompositeOperation = "destination-out";
            for (const side of [-1, 1]) {
                ctx.beginPath();
                ctx.ellipse(50 + side * 18 - 6, 44, 12, 9);
                ctx.fill();
            }
            ctx.beginPath();
            ctx.moveTo(50, 74);
            ctx.lineTo(43, 63);
            ctx.lineTo(57, 63);
            ctx.closePath();
            ctx.fill();

            ctx.restore();
        }
    }

    // A canvas paints on the next frame, not on the line after the colour
    // changes, so each mark is given a moment before it is grabbed.
    Timer {
        id: settle

        interval: 250
        onTriggered: win.save()
    }

    Component.onCompleted: {
        art.requestPaint();
        settle.start();
    }

    function save() {
        art.grabToImage(function (result) {
            result.saveToFile(outputDir + "/" + marks[index].name + ".png");
            console.log("saved " + marks[index].name);
            if (index + 1 < marks.length) {
                index = index + 1;
                art.requestPaint();
                settle.start();
            } else {
                Qt.callLater(Qt.quit);
            }
        }, Qt.size(64, 64));
    }
}
