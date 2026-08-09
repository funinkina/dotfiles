import Quickshell
import Quickshell.Wayland
import QtQuick

// Invisible full-screen catcher: any click outside the bar/dock closes
// whichever popout panel is open. Stacks below the panels (created first).
PanelWindow {
    id: layer
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dismiss"

    visible: ShellState.openPanel !== ""

    anchors { top: true; bottom: true; left: true; right: true }
    margins { top: Theme.barHeight; left: Theme.dockWidth }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closePanels()
    }
}
