import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 18
    implicitHeight: Theme.barHeight

    readonly property bool hasNotifs: NotifService.all.length > 0
    readonly property bool dnd: NotifService.dnd

    HoverBg {
        active: ShellState.isOpen("notifs", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    ColorIcon {
        id: bell
        anchors.centerIn: parent
        name: root.dnd ? "notification-disabled-symbolic" : "notification-symbolic"
        size: 16
        // Idle-but-silenced still reads at a glance; idle-and-listening stays quiet.
        tint: root.hasNotifs ? Theme.fg : root.dnd ? Theme.dim : Theme.faint
    }

    Rectangle {
        visible: root.hasNotifs
        anchors.right: bell.right
        anchors.rightMargin: -2
        anchors.top: bell.top
        anchors.topMargin: -2
        width: 7
        height: 7
        radius: 3.5
        color: Theme.fg
        border.color: Theme.bg
        border.width: 1
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("notifs", QsWindow.window?.screen?.name ?? "")
    }
}
