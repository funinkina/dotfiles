import QtQuick

// One selectable audio device: accent bar + name + tick on the active one.
Rectangle {
    id: root
    property var node
    property bool active: false
    signal chosen()

    readonly property string label:
        node ? (node.nickname || node.description || node.name) : ""

    height: 34
    radius: Theme.radius
    color: ma.pressed ? Theme.press : ma.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
        visible: root.active
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 18
        radius: 1.5
        color: Theme.accent
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: check.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.active ? Theme.fg : Theme.dim
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.weight: root.active ? Font.Medium : Font.Normal
        elide: Text.ElideRight
    }

    ColorIcon {
        id: check
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        name: "object-select-symbolic"
        size: 14
        tint: Theme.fg
        visible: root.active
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
