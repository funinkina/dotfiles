import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    property string netType: ""
    property string netName: "offline"
    property int netSignal: -1   // 0-100 for wifi, -1 when unknown

    // NetworkManager's own strength for the in-use AP, so the bars match what
    // other shells show. --rescan no keeps this a cached lookup rather than
    // kicking off a scan every poll. Signal is emitted before the connection
    // name because a name may itself contain colons.
    Process {
        id: nmProc
        command: ["sh", "-c",
            "line=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\"{print $1\":\"$3; exit}');"
            + " [ -n \"$line\" ] || exit 0;"
            + " type=${line%%:*}; name=${line#*:}; sig=;"
            + " [ \"$type\" = wifi ] && sig=$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}');"
            + " printf '%s:%s:%s\\n' \"$type\" \"$sig\" \"$name\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (!line) {
                    root.netType = "";
                    root.netSignal = -1;
                    root.netName = "offline";
                    return;
                }
                const a = line.indexOf(":");
                const b = line.indexOf(":", a + 1);
                const sig = line.slice(a + 1, b);
                root.netType = line.slice(0, a);
                root.netSignal = sig === "" ? -1 : parseInt(sig);
                root.netName = line.slice(b + 1) || root.netType;
            }
        }
    }

    // Same thresholds NetworkManager uses to pick its own icon.
    readonly property string netIcon: {
        if (netType === "ethernet")
            return "network-wired-symbolic";
        if (netType !== "wifi")
            return "network-offline-symbolic";
        if (netSignal < 0)
            return "network-wireless-signal-none-symbolic";
        if (netSignal >= 80)
            return "network-wireless-signal-excellent-symbolic";
        if (netSignal >= 55)
            return "network-wireless-signal-good-symbolic";
        if (netSignal >= 30)
            return "network-wireless-signal-ok-symbolic";
        if (netSignal >= 5)
            return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: nmProc.running = true
    }

    HoverBg {
        active: ShellState.isOpen("network", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ColorIcon {
            name: root.netIcon
            tint: root.netType ? Theme.fg : Theme.faint
            size: 16
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.netName
            color: root.netType ? Theme.fg : Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("network", QsWindow.window?.screen?.name ?? "")
    }
}
