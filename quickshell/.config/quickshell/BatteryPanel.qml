import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// Battery popout: charge state, technical details, power profile switcher.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-battery"

    visible: ShellState.openPanel === "battery"

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight
        right: ShellState.batteryX < 0 ? 16
            : Math.max(8, ShellState.screenW - ShellState.batteryX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    property var info: ({})
    property var rows: []

    onVisibleChanged: if (visible) upowerProc.running = true

    Timer {
        interval: 5000
        running: panel.visible
        repeat: true
        onTriggered: upowerProc.running = true
    }

    Process {
        id: upowerProc
        command: ["sh", "-c", "upower -i \"$(upower -e | grep -im1 bat)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s+([a-z-]+(?: [a-z]+)*):\s+(.+)$/i);
                    if (m)
                        d[m[1].trim()] = m[2].trim();
                }
                panel.info = d;
                const r = [];
                const add = (k, v) => { if (v) r.push({ k: k, v: v }); };
                add("Health", d["capacity"]);
                add("Full capacity", d["energy-full"]
                    + (d["energy-full-design"] ? ` (design ${d["energy-full-design"]})` : ""));
                add("Power draw", d["energy-rate"]);
                add("Voltage", d["voltage"]);
                add("Charge cycles", d["charge-cycles"]);
                add("Technology", d["technology"]);
                add("Model", d["model"]);
                panel.rows = r;
            }
        }
    }

    function stateLabel() {
        const s = info["state"] ?? "";
        const t = info["time to empty"] ?? info["time to full"] ?? "";
        const nice = s.replace("-", " ");
        if (s === "discharging" && t)
            return `Discharging · ${t} left`;
        if (s === "charging" && t)
            return `Charging · ${t} until full`;
        return nice.charAt(0).toUpperCase() + nice.slice(1);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 4

        Text {
            text: "Battery"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 4 }

        Text {
            text: info["percentage"] ?? "—"
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }

        Text {
            text: panel.stateLabel()
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Item { width: 1; height: 8 }

        Rectangle { width: parent.width; height: 1; color: Theme.faint }

        Item { width: 1; height: 8 }

        Repeater {
            model: panel.rows

            Item {
                required property var modelData
                width: col.width
                height: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.k
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.v
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
        }

        Item { width: 1; height: 8 }

        Rectangle { width: parent.width; height: 1; color: Theme.faint }

        Item { width: 1; height: 8 }

        Text {
            text: "Power profile"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 4 }

        Row {
            spacing: 6

            Repeater {
                model: [
                    { label: "Saver", val: PowerProfile.PowerSaver },
                    { label: "Balanced", val: PowerProfile.Balanced },
                    { label: "Performance", val: PowerProfile.Performance }
                ]

                Rectangle {
                    required property var modelData
                    readonly property bool active: PowerProfiles.profile === modelData.val
                    visible: modelData.val !== PowerProfile.Performance
                        || PowerProfiles.hasPerformanceProfile
                    width: label.implicitWidth + 20
                    height: 26
                    radius: 5
                    color: active ? Theme.accent
                        : profMouse.containsMouse ? "#2a2a2a" : "#161616"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.active ? "#000000" : Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: profMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: PowerProfiles.profile = parent.modelData.val
                    }
                }
            }
        }
    }
}
