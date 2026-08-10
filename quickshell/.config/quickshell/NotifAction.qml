import QtQuick

// One notification action button. Outlined rather than filled so it reads on
// both the popup card (Theme.bg) and the notification center card
// (Theme.surface), including while the popup card is hovered.
Rectangle {
    id: root
    required property var action

    implicitWidth: Math.min(label.implicitWidth + 20, 160)
    implicitHeight: 26
    radius: Theme.radius - 2
    color: ma.pressed ? Theme.press : ma.containsMouse ? Theme.hover : "transparent"
    border.color: ma.containsMouse ? Theme.borderBright : Theme.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - 16)
        text: root.action.text || root.action.identifier
        color: ma.containsMouse ? Theme.fg : Theme.dim
        font.family: Theme.uiFont
        font.pixelSize: 12
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // invoke() closes the notification itself unless it is resident.
        onClicked: root.action.invoke()
    }
}
