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

    // Hairline separating the bar from window content
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.line
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
    readonly property real winX: contentArea.x + focusedApp.x + focusedApp.width / 2

    onVolXChanged: ShellState.setAnchor(sname, "volume", volX)
    onWinXChanged: ShellState.setAnchor(sname, "window", winX)
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
        ShellState.setAnchor(sname, "window", winX);
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

                HoverBg { pressed: archMouse.pressed }

                Image {
                    anchors.centerIn: parent
                    source: "file:///usr/share/pixmaps/archlinux-logo.svg"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    opacity: archMouse.containsMouse ? 1.0 : 0.85
                    scale: archMouse.pressed ? 0.9 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: archMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.dispatch(["toggle-overview"])
                }
            }

            WorkspaceDots { screenName: bar.screen?.name ?? "" }
            PrivacyWidget {}
            MediaWidget { id: mediaW }
        }

        FocusedApp {
            id: focusedApp
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
