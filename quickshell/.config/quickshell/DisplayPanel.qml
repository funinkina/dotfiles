import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Display popout: brightness slider + refresh rate switcher.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-display"

    visible: ShellState.openPanel === "display"

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: ShellState.brightnessX < 0 ? 16
            : Math.max(8, ShellState.screenW - ShellState.brightnessX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    // [{ label, mode, active }] for the current resolution
    property var rates: []

    onVisibleChanged: if (visible) outProc.running = true

    Process {
        id: outProc
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let outs;
                try { outs = JSON.parse(text); } catch (e) { return; }
                const o = outs[panel.screen?.name] ?? Object.values(outs)[0];
                if (!o)
                    return;
                const cm = o.modes[o.current_mode];
                panel.rates = o.modes
                    .filter(m => m.width === cm.width && m.height === cm.height)
                    .sort((a, b) => a.refresh_rate - b.refresh_rate)
                    .map(m => ({
                        label: Math.round(m.refresh_rate / 1000) + " Hz",
                        mode: `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`,
                        active: m.refresh_rate === cm.refresh_rate
                    }));
            }
        }
    }

    Timer {
        id: refetchTimer
        interval: 600
        onTriggered: outProc.running = true
    }

    function setMode(mode) {
        Quickshell.execDetached(["niri", "msg", "output",
            panel.screen?.name ?? "eDP-1", "mode", mode]);
        refetchTimer.restart();
    }

    // Brightness
    readonly property int bCur: parseInt(bFile.text()) || 0
    readonly property int bMax: parseInt(bMaxFile.text()) || 1
    readonly property real bVal: bCur / bMax

    FileView {
        id: bFile
        path: "/sys/class/backlight/intel_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: bMaxFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    function setBrightness(v) {
        v = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "set",
            Math.round(v * 100) + "%"]);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6

        Text {
            text: "Brightness"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 2 }

        Item {
            width: parent.width
            height: 22

            ColorIcon {
                id: bIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: 16
                name: "display-brightness-symbolic"
            }

            Text {
                id: bPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(panel.bVal * 100) + "%"
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 12
            }

            Item {
                anchors.left: bIcon.right
                anchors.right: bPct.left
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: parent.height

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    color: Theme.faint

                    Rectangle {
                        width: parent.width * Math.min(1, panel.bVal)
                        height: parent.height
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => panel.setBrightness(mouse.x / width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            panel.setBrightness(mouse.x / width);
                    }
                    onWheel: wheel => panel.setBrightness(
                        panel.bVal + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }

        Item { width: 1; height: 10 }

        Text {
            text: "Refresh rate"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 4 }

        // Full-width segmented switcher, same style as power profiles
        Rectangle {
            id: segments
            width: parent.width
            height: 30
            color: "transparent"
            border.color: Theme.faint
            border.width: 1
            visible: panel.rates.length > 0

            Row {
                anchors.fill: parent
                anchors.margins: 1

                Repeater {
                    model: panel.rates

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width / panel.rates.length
                        height: parent.height
                        color: modelData.active ? Theme.accent
                            : segMouse.containsMouse ? "#1f1f1f" : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            visible: parent.index > 0
                            anchors.left: parent.left
                            width: 1
                            height: parent.height
                            color: Theme.faint
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.modelData.active ? "#000000" : Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.setMode(parent.modelData.mode)
                        }
                    }
                }
            }
        }
    }
}
