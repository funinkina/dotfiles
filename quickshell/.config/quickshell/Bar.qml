import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-bar"

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    readonly property string sname: bar.screen?.name ?? ""
    readonly property real volX: contentArea.x + rightRow.x + audioW.x + audioW.width / 2
    readonly property real briX: contentArea.x + rightRow.x + backlightW.x + backlightW.width / 2
    readonly property real netX: contentArea.x + rightRow.x + netW.x + netW.width / 2
    readonly property real battX: contentArea.x + rightRow.x + battW.x + battW.width / 2
    readonly property real btX: contentArea.x + rightRow.x + btW.x + btW.width / 2
    readonly property real clkX: contentArea.x + rightRow.x + clockW.x + clockW.width / 2
    readonly property real weaX: contentArea.x + rightRow.x + weatherW.x + weatherW.width / 2
    readonly property real medX: contentArea.x + leftRow.x + mediaW.x + mediaW.width / 2

    onVolXChanged: ShellState.setAnchor(sname, "volume", volX)
    onBriXChanged: ShellState.setAnchor(sname, "brightness", briX)
    onNetXChanged: ShellState.setAnchor(sname, "network", netX)
    onBattXChanged: ShellState.setAnchor(sname, "battery", battX)
    onBtXChanged: ShellState.setAnchor(sname, "bluetooth", btX)
    onClkXChanged: ShellState.setAnchor(sname, "clock", clkX)
    onWeaXChanged: ShellState.setAnchor(sname, "weather", weaX)
    onMedXChanged: ShellState.setAnchor(sname, "media", medX)

    Component.onCompleted: {
        ShellState.setAnchor(sname, "volume", volX);
        ShellState.setAnchor(sname, "brightness", briX);
        ShellState.setAnchor(sname, "network", netX);
        ShellState.setAnchor(sname, "battery", battX);
        ShellState.setAnchor(sname, "bluetooth", btX);
        ShellState.setAnchor(sname, "clock", clkX);
        ShellState.setAnchor(sname, "weather", weaX);
        ShellState.setAnchor(sname, "media", medX);
    }

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        RowLayout {
            id: leftRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            // Arch logo: overview toggle
            Item {
                implicitWidth: 20
                implicitHeight: Theme.barHeight

                HoverBg {}

                Image {
                    anchors.centerIn: parent
                    source: "file:///usr/share/pixmaps/archlinux-logo.svg"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    opacity: archMouse.containsMouse ? 1.0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: archMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: NiriService.dispatch(["toggle-overview"])
                }
            }

            WorkspaceDots { screenName: bar.screen?.name ?? "" }
            PrivacyWidget {}
            MediaWidget { id: mediaW }
        }

        FocusedApp {
            anchors.centerIn: parent
        }

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            TrayWidget {}
            AudioWidget { id: audioW }
            BacklightWidget { id: backlightW }
            NetworkWidget { id: netW }
            BluetoothWidget { id: btW }
            BatteryWidget { id: battW }
            WeatherWidget { id: weatherW }
            ClockWidget { id: clockW }
            NotifWidget {}
        }
    }
}
