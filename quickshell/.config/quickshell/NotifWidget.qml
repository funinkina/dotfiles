import QtQuick
import Quickshell

// Bar bell: dim when idle, white with a dot badge when notifications exist.
Item {
    id: root
    implicitWidth: 18
    implicitHeight: Theme.barHeight

    readonly property bool hasNotifs: NotifService.all.length > 0

    HoverBg {}

    ColorIcon {
        id: bell
        anchors.centerIn: parent
        name: "preferences-system-notifications-symbolic"
        size: 16
        tint: root.hasNotifs ? Theme.fg : Theme.faint
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
        anchors.fill: parent
        anchors.margins: -8
        onClicked: ShellState.togglePanel("notifs", QsWindow.window?.screen?.name ?? "")
    }
}
