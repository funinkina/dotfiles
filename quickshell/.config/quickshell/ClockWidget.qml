import QtQuick
import Quickshell

Item {
    implicitWidth: t.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverBg {
        active: ShellState.isOpen("clock", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    Text {
        id: t
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM∙HH:mm")
        color: Theme.fg
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("clock", QsWindow.window?.screen?.name ?? "")
    }
}
