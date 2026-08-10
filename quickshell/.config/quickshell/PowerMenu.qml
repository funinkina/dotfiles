import Quickshell
import Quickshell.Wayland
import QtQuick

// Centered power menu: shutdown / restart / suspend / logout / lock.
// Keyboard: ←/→ move selection, Enter activates, Esc closes.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "power"
        && (ShellState.panelScreen === "" || ShellState.panelScreen === sname)

    // No anchors: layer-shell centers the surface on screen
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: row.implicitWidth + 32
    implicitHeight: row.implicitHeight + 32
    color: "transparent"

    readonly property var entries: [
        { icon: "system-shutdown-symbolic", label: "Shut Down", action: "poweroff" },
        { icon: "system-reboot-symbolic", label: "Restart", action: "reboot" },
        { icon: "weather-clear-night-symbolic", label: "Suspend", action: "suspend" },
        { icon: "system-log-out-symbolic", label: "Log Out", action: "logout" },
        { icon: "system-lock-screen-symbolic", label: "Lock", action: "lock" }
    ]

    property int selected: 0
    onVisibleChanged: if (visible) selected = 0

    function act(action) {
        ShellState.closePanels();
        if (action === "lock")
            LockService.lock();
        else if (action === "logout")
            NiriService.dispatch(["quit", "--skip-confirmation"]);
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    PanelSurface { id: surf }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: panel.selected =
            (panel.selected + panel.entries.length - 1) % panel.entries.length
        Keys.onRightPressed: panel.selected =
            (panel.selected + 1) % panel.entries.length
        Keys.onReturnPressed: panel.act(panel.entries[panel.selected].action)
        Keys.onEnterPressed: panel.act(panel.entries[panel.selected].action)
        Keys.onSpacePressed: panel.act(panel.entries[panel.selected].action)
        Keys.onEscapePressed: ShellState.closePanels()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        opacity: surf.opacity

        Repeater {
            model: panel.entries

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool current: panel.selected === index
                width: 104
                height: 96
                color: tileMouse.pressed ? Theme.press
                    : current || tileMouse.containsMouse ? Theme.hover : Theme.surface
                border.color: current ? Theme.fg : Theme.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: 100 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    ColorIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: parent.parent.modelData.icon
                        size: 28
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.parent.modelData.label
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: panel.selected = parent.index
                    onClicked: panel.act(parent.modelData.action)
                }
            }
        }
    }
}
