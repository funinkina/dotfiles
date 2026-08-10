import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Wi-Fi popout: current connection details, nearby networks (scrollable),
// connect to saved/open networks directly or via inline password entry.
// All scanning/polling stops while the panel is closed.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-network"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "network" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.network ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: Math.min(540, col.implicitHeight + 28)
    color: "transparent"

    property string ip: ""
    property bool wifiOn: true
    property var nets: []
    property var saved: []
    readonly property var current: nets.find(n => n.active) ?? null
    readonly property var others: nets.filter(n => !n.active)

    // Inline connect state
    property string expandedSsid: ""
    property string connError: ""

    onVisibleChanged: {
        if (visible) {
            radioProc.running = true;
            refresh();
            savedProc.running = true;
            scanProc.running = true;
        } else {
            expandedSsid = "";
            connError = "";
            rxPrev = -1;
            downSpeed = "";
            upSpeed = "";
        }
    }

    function refresh() {
        // Freeze list updates while a password field is open
        if (expandedSsid !== "")
            return;
        listProc.running = true;
        ipProc.running = true;
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: panel.wifiOn = text.trim() === "enabled"
        }
    }

    function setWifi(on) {
        wifiOn = on;
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        if (on) {
            scanTimer.restart();
        } else {
            nets = [];
        }
    }

    Timer {
        id: scanTimer
        interval: 1500
        onTriggered: {
            scanProc.running = true;
            panel.refresh();
        }
    }

    function connect(ssid, password) {
        connError = "";
        connProc.command = password
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }

    Process {
        id: connProc
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: connProc.errText = text.trim() }
        onExited: code => {
            if (code === 0) {
                panel.expandedSsid = "";
                panel.savedProc.running = true;
                panel.refresh();
            } else {
                panel.connError = errText.replace(/^Error: /, "") || "Failed to connect";
            }
        }
    }

    property alias savedProc: savedProc
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: panel.saved =
                text.trim().split("\n").map(l => l.replace(/\\:/g, ":"))
        }
    }

    // One-shot rescan (on open), then periodic while open
    Process {
        id: scanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: relistTimer.restart()
    }

    Timer {
        id: relistTimer
        interval: 2500
        onTriggered: if (panel.visible) panel.refresh()
    }

    Timer {
        interval: 15000
        running: panel.visible
        repeat: true
        onTriggered: scanProc.running = true
    }

    Timer {
        interval: 8000
        running: panel.visible
        repeat: true
        onTriggered: panel.refresh()
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,FREQ,RATE,SECURITY,SSID",
            "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bySsid = new Map();
                for (const line of text.trim().split("\n")) {
                    const p = line.split(":");
                    if (p.length < 6)
                        continue;
                    const n = {
                        active: p[0] === "yes",
                        signal: parseInt(p[1]) || 0,
                        freq: parseInt(p[2]) || 0,
                        rate: p[3],
                        sec: p[4],
                        ssid: p.slice(5).join(":").replace(/\\:/g, ":")
                    };
                    if (!n.ssid)
                        continue;
                    const prev = bySsid.get(n.ssid);
                    if (!prev || n.active || (!prev.active && n.signal > prev.signal))
                        bySsid.set(n.ssid, prev?.active ? prev : n);
                }
                panel.nets = [...bySsid.values()].sort((a, b) =>
                    (b.active - a.active) || (b.signal - a.signal)).slice(0, 20);
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

    // Live throughput from the wifi interface's byte counters
    property real rxPrev: -1
    property real txPrev: -1
    property real prevT: 0
    property string downSpeed: ""
    property string upSpeed: ""

    function fmtSpeed(b) {
        if (b < 1024)
            return Math.round(b) + " B/s";
        if (b < 1048576)
            return (b / 1024).toFixed(0) + " KB/s";
        return (b / 1048576).toFixed(1) + " MB/s";
    }

    Process {
        id: speedProc
        command: ["sh", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"wifi\"{print $1; exit}'); cat /sys/class/net/$dev/statistics/rx_bytes /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n").map(Number);
                if (v.length < 2 || isNaN(v[0]) || isNaN(v[1]))
                    return;
                const now = Date.now();
                if (panel.rxPrev >= 0) {
                    const dt = (now - panel.prevT) / 1000;
                    if (dt > 0.2) {
                        panel.downSpeed = panel.fmtSpeed(Math.max(0, v[0] - panel.rxPrev) / dt);
                        panel.upSpeed = panel.fmtSpeed(Math.max(0, v[1] - panel.txPrev) / dt);
                    }
                }
                panel.rxPrev = v[0];
                panel.txPrev = v[1];
                panel.prevT = now;
            }
        }
    }

    Timer {
        interval: 2000
        running: panel.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: speedProc.running = true
    }

    PanelSurface { id: surf }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        focus: true
        opacity: surf.opacity
        // Esc: collapse an open password row first, then close the panel
        Keys.onEscapePressed: {
            if (panel.expandedSsid !== "")
                panel.expandedSsid = "";
            else
                ShellState.closePanels();
        }

        Column {
            id: col
            width: flick.width
            spacing: 4

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 92
                    height: 22
                    color: "transparent"
                    border.color: Theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 1

                        Repeater {
                            model: [
                                { label: "On", val: true },
                                { label: "Off", val: false }
                            ]

                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool active: panel.wifiOn === modelData.val
                                width: parent.width / 2
                                height: parent.height
                                color: active ? Theme.accent
                                    : wtMouse.pressed ? Theme.press
                                    : wtMouse.containsMouse ? Theme.hover : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    visible: parent.index > 0
                                    anchors.left: parent.left
                                    width: 1
                                    height: parent.height
                                    color: Theme.line
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: parent.active ? Theme.accentFg : Theme.fg
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: wtMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.setWifi(parent.modelData.val)
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            Text {
                text: !panel.wifiOn ? "Wi-Fi is off"
                    : panel.current ? panel.current.ssid : "Not connected"
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
                width: parent.width
                elide: Text.ElideRight
            }

            Text {
                visible: panel.current !== null
                text: {
                    const c = panel.current;
                    if (!c)
                        return "";
                    const lines = [`${c.signal}% signal · ${panel.band(c.freq)}`
                        + (c.sec ? ` · ${c.sec}` : "")];
                    if (c.rate)
                        lines.push(`Link speed ${c.rate}`);
                    if (panel.ip)
                        lines.push(panel.ip);
                    if (panel.downSpeed)
                        lines.push(`↓ ${panel.downSpeed}   ↑ ${panel.upSpeed}`);
                    return lines.join("\n");
                }
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                lineHeight: 1.3
            }

            Item { width: 1; height: 8 }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            Item { width: 1; height: 8 }

            Text {
                text: "Nearby networks"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                visible: panel.wifiOn && panel.others.length > 0
            }

            Item { width: 1; height: 2 }

            Repeater {
                model: panel.others

                Column {
                    id: netItem
                    required property var modelData
                    readonly property bool expanded:
                        panel.expandedSsid === modelData.ssid
                    width: col.width

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: netItem.expanded ? 0 : Theme.radius
                        color: rowMouse.pressed ? Theme.press
                            : rowMouse.containsMouse || netItem.expanded
                            ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.right: rightInfo.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: netItem.modelData.ssid
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
                                visible: netItem.modelData.sec !== ""
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.modelData.signal + "%"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = netItem.modelData;
                                panel.connError = "";
                                if (panel.saved.includes(n.ssid))
                                    panel.connect(n.ssid);
                                else if (n.sec === "")
                                    panel.connect(n.ssid);
                                else
                                    panel.expandedSsid = netItem.expanded ? "" : n.ssid;
                            }
                        }
                    }

                    // Inline password entry for new secured networks
                    Rectangle {
                        visible: netItem.expanded
                        width: parent.width
                        height: 36
                        color: Theme.surface
                        border.color: pwIn.activeFocus ? Theme.borderBright : Theme.border
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        onVisibleChanged: if (visible) pwIn.forceActiveFocus()

                        TextInput {
                            id: pwIn
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: connBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            clip: true
                            onAccepted: panel.connect(netItem.modelData.ssid, text)

                            Text {
                                visible: pwIn.text === "" && !pwIn.activeFocus
                                text: "Password"
                                color: Theme.faint
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            id: connBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: btnLabel.implicitWidth + 16
                            height: 24
                            radius: Theme.radius - 2
                            color: btnMouse.pressed ? Theme.dim
                                : btnMouse.containsMouse ? Theme.fg : Theme.press
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                id: btnLabel
                                anchors.centerIn: parent
                                text: connProc.running ? "…" : "Connect"
                                color: btnMouse.containsMouse || btnMouse.pressed
                                    ? Theme.accentFg : Theme.fg
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.connect(netItem.modelData.ssid, pwIn.text)
                            }
                        }
                    }

                    Text {
                        visible: netItem.expanded && panel.connError !== ""
                        width: parent.width
                        text: panel.connError
                        color: Theme.urgent
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        topPadding: 4
                    }
                }
            }

            Text {
                visible: panel.wifiOn && panel.others.length === 0
                text: "No other networks found"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
