import QtQuick
import QtQuick.Layouts

// A soft card. Every grouped block in the program sits in one of these, which
// is most of what makes the layout read as one design rather than a stack of
// controls.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: Math.round(13 * Theme.scale)
    property color tint: Theme.card
    property alias columnSpacing: inner.spacing

    implicitWidth: inner.implicitWidth + padding * 2
    implicitHeight: inner.implicitHeight + padding * 2

    color: tint
    radius: Theme.radius
    border.width: 1
    border.color: Theme.line

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Math.round(9 * Theme.scale)
    }
}
