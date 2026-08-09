import QtQuick

// Subtle hover background for bar items. Drop into any Item-rooted widget;
// extends slightly past the content and sits behind it.
Item {
    anchors.fill: parent
    anchors.leftMargin: -8
    anchors.rightMargin: -8
    anchors.topMargin: -5
    anchors.bottomMargin: -5
    z: -1

    Rectangle {
        anchors.fill: parent
        radius: 5
        color: hh.hovered ? "#1f1f1f" : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { id: hh }
}
