import Quickshell
import Quickshell.Wayland
import QtQuick

// Invisible click-away catcher for the popout panels.
// Always mapped (so it stays stacked BELOW the panels, which map later);
// only its input mask toggles. When no panel is open the mask is empty and
// every click passes through; when one is open, clicks outside the panels
// land here and close them. Excludes the bar and dock via margins.
PanelWindow {
    id: layer
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dismiss"

    // Take the keyboard while a panel is open so Escape can close it.
    // Network (password entry), power (arrow nav), clock (weather city entry)
    // and launcher (search field) manage their own.
    // The window panel must NOT grab: grabbing unfocuses the window in niri,
    // which would null focusedWindow and close the panel instantly.
    readonly property var selfGrabbing:
        ["network", "power", "clock", "window", "launcher"]

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
