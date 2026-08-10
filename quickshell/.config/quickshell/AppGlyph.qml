import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

// The sending app's icon at text size, for the notification header row.
// Flat-tinted when the icon theme has a symbolic variant, left in its own
// colors when it doesn't — ColorOverlay on a full-color logo is a blob.
Item {
    id: root
    required property var notification
    property color tint: Theme.muted
    property int size: 12

    readonly property var glyph: NotifService.appGlyph(notification)

    implicitWidth: size
    implicitHeight: size
    visible: glyph.path !== ""

    IconImage {
        id: img
        anchors.fill: parent
        source: root.glyph.path
        visible: !root.glyph.symbolic
    }

    ColorOverlay {
        anchors.fill: parent
        source: img
        color: root.tint
        visible: root.glyph.symbolic
    }
}
