import QtQuick

// Hover/active/pressed pill behind bar items. Widgets span the full bar
// height; the pill is inset vertically and extends sideways past content.
// `active` marks the widget whose popout panel is currently open.
Item {
    id: root
    property bool active: false
    property bool pressed: false

    anchors.fill: parent
    anchors.leftMargin: -8
    anchors.rightMargin: -8
    z: -1

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: Theme.radius
        color: root.pressed || root.active ? Theme.press
            : hh.hovered ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { id: hh }
}
