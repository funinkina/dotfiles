import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Wi-Fi popout: current connection details + nearby networks.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-network"

    visible: ShellState.openPanel === "network"

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight
        right: ShellState.networkX < 0 ? 16
            : Math.max(8, ShellState.screenW - ShellState.networkX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: Math.min(520, col.implicitHeight + 28)
    color: "transparent"

    property string ip: ""
    property var nets: []
    readonly property var current: nets.find(n => n.active) ?? null
    readonly property var others: nets.filter(n => !n.active)

    onVisibleChanged: if (visible) refresh()

    function refresh() {
        listProc.running = true;
        ipProc.running = true;
    }

    Timer {
        interval: 8000
        running: panel.visible
        repeat: true
        onTriggered: panel.refresh()
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,FREQ,SECURITY,SSID",
            "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bySsid = new Map();
                for (const line of text.trim().split("\n")) {
                    const p = line.split(":");
                    if (p.length < 5)
                        continue;
                    const n = {
                        active: p[0] === "yes",
                        signal: parseInt(p[1]) || 0,
                        freq: parseInt(p[2]) || 0,
                        sec: p[3],
                        ssid: p.slice(4).join(":").replace(/\\:/g, ":")
                    };
                    if (!n.ssid)
                        continue;
                    const prev = bySsid.get(n.ssid);
                    if (!prev || n.active || (!prev.active && n.signal > prev.signal))
                        bySsid.set(n.ssid, prev?.active ? prev : n);
                }
                panel.nets = [...bySsid.values()].sort((a, b) =>
                    (b.active - a.active) || (b.signal - a.signal)).slice(0, 12);
            }
        }
    }

    Process {
        id: ipProc
        command: ["sh", "-c",
            "nmcli -t -f IP4.ADDRESS dev show \"$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"wifi\"{print $1; exit}')\" 2>/dev/null | head -1 | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: panel.ip = text.trim()
        }
    }

    function band(freq) {
        return freq > 5900 ? "6 GHz" : freq > 3000 ? "5 GHz" : "2.4 GHz";
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
            text: "Wi-Fi"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 4 }

        Text {
            text: panel.current ? panel.current.ssid : "Not connected"
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
            width: parent.width
            elide: Text.ElideRight
        }

        Text {
            visible: panel.current !== null
            text: panel.current
                ? `${panel.current.signal}% signal · ${panel.band(panel.current.freq)}`
                  + (panel.current.sec ? ` · ${panel.current.sec}` : "")
                  + (panel.ip ? `\n${panel.ip}` : "")
                : ""
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            lineHeight: 1.3
        }

        Item { width: 1; height: 8 }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.faint
        }

        Item { width: 1; height: 8 }

        Text {
            text: "Nearby networks"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            visible: panel.others.length > 0
        }

        Item { width: 1; height: 2 }

        Repeater {
            model: panel.others

            Rectangle {
                required property var modelData
                width: col.width
                height: 32
                color: rowMouse.containsMouse ? "#1a1a1a" : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: rightInfo.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.ssid
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Row {
                    id: rightInfo
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ColorIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "network-wireless-encrypted-symbolic"
                        size: 12
                        tint: Theme.muted
                        visible: parent.parent.modelData.sec !== ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.modelData.signal + "%"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    // Connects if the network is already saved in NetworkManager
                    onClicked: Quickshell.execDetached(
                        ["nmcli", "connection", "up", "id", parent.modelData.ssid])
                }
            }
        }

        Text {
            visible: panel.others.length === 0
            text: "No other networks found"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
}
