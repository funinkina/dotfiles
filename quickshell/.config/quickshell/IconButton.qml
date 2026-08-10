import QtQuick

// Symbolic icon that behaves like a button: springs on hover, dips on press.
// Set `enabled: false` to grey it out and stop it taking clicks.
Item {
    id: root
    property string icon
    property int size: 22
    signal clicked()

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: 100 } }

    ColorIcon {
        anchors.centerIn: parent
        name: root.icon
        size: root.size
        scale: ma.pressed ? 0.85 : ma.containsMouse ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
