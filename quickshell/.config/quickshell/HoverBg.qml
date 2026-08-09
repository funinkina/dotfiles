import QtQuick

// Subtle hover background for bar items. Widgets span the full bar height,
// so this reaches the screen edge; extends a little sideways past content.
Item {
    anchors.fill: parent
    anchors.leftMargin: -8
    anchors.rightMargin: -8
    z: -1

    Rectangle {
        anchors.fill: parent
        color: hh.hovered ? "#1f1f1f" : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { id: hh }
}
