import QtQuick
import QtQuick.Window
import Ocelot

// The program's icon, rendered from the ocelot the program itself draws, so the
// two can never drift apart.
//
// Two drawings, not one. Large sizes get the face as it appears in the window;
// at 32 pixels and below that face turns to porridge, so those sizes get the
// silhouette instead - the same shape the notification area uses. Windows picks
// whichever size it needs, and both look deliberate.
//
// The module has to be on the import path. Qt's own copy inside the build
// directory prefers the compiled resources, so make a plain one first:
//
//   mkdir -p /tmp/iconmod/Ocelot && cp src/qml/*.qml /tmp/iconmod/Ocelot/
//   { echo "module Ocelot";
//     for f in /tmp/iconmod/Ocelot/*.qml; do n=$(basename "$f" .qml);
//       case "$n" in Theme|Telemetry) echo "singleton $n 1.0 $n.qml";;
//       *) echo "$n 1.0 $n.qml";; esac; done; } > /tmp/iconmod/Ocelot/qmldir
//   qml -I /tmp/iconmod contrib/icons/app-icon.qml
//
// The PNGs then go into src/ocelot.ico; contrib/icons/pack-ico.py does that.
Window {
    id: win

    readonly property var sizes: [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    property int index: 0

    visible: true
    width: 512
    height: 512
    color: "#00000000"

    // A warm disc, so the mark reads against a dark taskbar as well as a light
    // one, with the brand's amber as its edge.
    component Disc: Item {
        default property alias content: holder.data

        width: 512
        height: 512

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#fff3df" }
                GradientStop { position: 1.0; color: "#f6d7a8" }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.round(parent.width * 0.03)
            border.color: "#e88f34"
        }

        Item {
            id: holder

            anchors.fill: parent
        }
    }

    Disc {
        id: detailed

        Mascot {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Math.round(parent.height * 0.03)
            mood: "happy"
            halo: false
            size: Math.round(parent.width * 0.99)
        }
    }

    Disc {
        id: simple

        visible: false

        Canvas {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.62)
            height: width
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                const k = width / 100;
                ctx.reset();
                ctx.save();
                ctx.scale(k, k);
                ctx.fillStyle = "#7f542e";

                for (const side of [-1, 1]) {
                    ctx.beginPath();
                    ctx.moveTo(50 + side * 12, 30);
                    ctx.lineTo(50 + side * 34, 8);
                    ctx.lineTo(50 + side * 36, 42);
                    ctx.closePath();
                    ctx.fill();
                }

                ctx.beginPath();
                ctx.moveTo(50, 22);
                ctx.bezierCurveTo(74, 22, 86, 36, 86, 52);
                ctx.bezierCurveTo(86, 70, 72, 88, 50, 88);
                ctx.bezierCurveTo(28, 88, 14, 70, 14, 52);
                ctx.bezierCurveTo(14, 36, 26, 22, 50, 22);
                ctx.closePath();
                ctx.fill();

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
    }

    Component.onCompleted: saveNext()

    function saveNext() {
        if (index >= sizes.length) {
            Qt.callLater(Qt.quit);
            return;
        }

        const side = sizes[index];
        const source = side <= 40 ? simple : detailed;
        source.grabToImage(function (result) {
            result.saveToFile(outputDir + "/ocelot-" + side + ".png");
            console.log("saved " + side);
            index = index + 1;
            Qt.callLater(saveNext);
        }, Qt.size(side, side));
    }
}
