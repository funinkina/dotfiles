import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._BackgroundEffect
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
    implicitWidth: row.implicitWidth + 40
    implicitHeight: row.implicitHeight + 40
    color: "transparent"

    // Compositor blur, same protocol as the bar. The region carries the
    // panel's own radius so the blur stops at the rounded edge instead of
    // squaring off the corners.
    BackgroundEffect.blurRegion: Region {
        width: panel.width
        height: panel.height
        radius: Theme.panelRadius
    }

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
        else {
            // Asking for this explicitly beats caffeine. `-i` skips the block
            // inhibitor too, so suspend doesn't race the lock being dropped.
            const wasCaf = CaffeineService.active;
            CaffeineService.setActive(false);
            Quickshell.execDetached(wasCaf && action === "suspend"
                ? ["systemctl", "-i", action] : ["systemctl", action]);
        }
    }

    PanelSurface { id: surf; tint: Theme.barBg }

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
                width: 100
                height: 92
                radius: Theme.radius
                // No idle fill or outline: a filled tile would sit on top of
                // the blur and hide it. Only the selected one gets a pill,
                // and hovering moves the selection anyway.
                color: tileMouse.pressed || current ? Theme.press : "transparent"

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
