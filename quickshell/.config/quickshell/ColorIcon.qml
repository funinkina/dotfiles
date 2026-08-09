import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

// Icon-theme icon repainted in a flat tint via its alpha channel,
// regardless of the icon's own colors.
Item {
    id: root
    property string name
    property color tint: Theme.fg
    property int size: 16

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        source: root.name ? Quickshell.iconPath(root.name, "image-missing") : ""
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: img
        color: root.tint
    }
}
