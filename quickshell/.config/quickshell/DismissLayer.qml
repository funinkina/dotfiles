import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: layer
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dismiss"

    readonly property var selfGrabbing:
        ["network", "power", "clock", "window", "launcher", "clipboard"]

    WlrLayershell.keyboardFocus:
        ShellState.openPanel !== ""
            && !selfGrabbing.includes(ShellState.openPanel)
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    margins { top: Theme.barHeight; left: Theme.dockWidth }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: ShellState.openPanel !== "" ? null : emptyRegion

    Region { id: emptyRegion }

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closePanels()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.closePanels()
    }
}
