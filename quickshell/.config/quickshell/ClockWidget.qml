import QtQuick
import Quickshell

Item {
    implicitWidth: t.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverBg {}

    Text {
        id: t
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
        color: Theme.fg
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        onClicked: ShellState.togglePanel("clock")
    }
}
