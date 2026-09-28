import QtQuick

// A small state chip: "DTLS", an address, an uptime.
Rectangle {
    id: root

    property string text: ""
    property color tint: Theme.muted
    property string glyph: ""

    implicitWidth: row.implicitWidth + Math.round(14 * Theme.scale)
    implicitHeight: Math.round(20 * Theme.scale)
    radius: height / 2
    color: Qt.alpha(root.tint, Theme.night ? 0.22 : 0.14)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Glyph {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            color: root.tint
            size: Math.round(10 * Theme.scale)
            thickness: 1.6
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            font.weight: Font.Medium
        }
    }
}
