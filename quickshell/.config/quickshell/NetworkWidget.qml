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

    Process {
        id: nmProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\"{print $1\":\"$3; exit}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (!line) {
                    root.netType = "";
                    root.netName = "offline";
                    return;
                }
                const i = line.indexOf(":");
                root.netType = line.slice(0, i);
                root.netName = line.slice(i + 1) || root.netType;
            }
        }
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
            name: root.netType === "wifi" ? "network-wireless-symbolic"
                : root.netType === "ethernet" ? "network-wired-symbolic"
                : "network-offline-symbolic"
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
