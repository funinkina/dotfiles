import QtQuick

// Caffeine indicator: only on the bar while sleep is inhibited. Click to stop.
Item {
    implicitWidth: 20
    implicitHeight: Theme.barHeight
    visible: CaffeineService.active

    HoverBg { pressed: ma.pressed }

    ColorIcon {
        anchors.centerIn: parent
        name: "my-caffeine-on-symbolic"
        size: 15
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: CaffeineService.toggle()
    }
}
