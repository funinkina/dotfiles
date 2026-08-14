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
    implicitHeight: Theme.barHeight + Theme.panelRadius
    exclusiveZone: Theme.barHeight
    color: "transparent"

    mask: Region {
        width: bar.width
        height: Theme.barHeight
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight
        color: Theme.bg
    }

    CornerFillet {
        anchors.left: parent.left
        y: Theme.barHeight
        visible: !ShellState.dockVisible
    }
    CornerFillet {
        x: Theme.dockWidth
        y: Theme.barHeight
        visible: ShellState.dockVisible
    }
    CornerFillet {
        anchors.right: parent.right
        y: Theme.barHeight
        mirrored: true
    }

    readonly property string sname: bar.screen?.name ?? ""
    readonly property real volX: contentArea.x + rightRow.x + audioW.x + audioW.width / 2
    readonly property real briX: contentArea.x + rightRow.x + backlightW.x + backlightW.width / 2
    readonly property real netX: contentArea.x + rightRow.x + netW.x + netW.width / 2
    readonly property real battX: contentArea.x + rightRow.x + battW.x + battW.width / 2
    readonly property real btX: contentArea.x + rightRow.x + btW.x + btW.width / 2
    readonly property real clkX: contentArea.x + centerRow.x + clockW.x + clockW.width / 2
    readonly property real medX: contentArea.x + leftRow.x + mediaW.x + mediaW.width / 2
    readonly property real winX: contentArea.x + leftRow.x + focusedApp.x + focusedApp.width / 2
    readonly property real claX: contentArea.x + rightRow.x + claudeW.x + claudeW.width / 2

    onVolXChanged: ShellState.setAnchor(sname, "volume", volX)
    onWinXChanged: ShellState.setAnchor(sname, "window", winX)
    onClaXChanged: ShellState.setAnchor(sname, "claude", claX)
    onBriXChanged: ShellState.setAnchor(sname, "brightness", briX)
    onNetXChanged: ShellState.setAnchor(sname, "network", netX)
    onBattXChanged: ShellState.setAnchor(sname, "battery", battX)
    onBtXChanged: ShellState.setAnchor(sname, "bluetooth", btX)
    onClkXChanged: ShellState.setAnchor(sname, "clock", clkX)
    onMedXChanged: ShellState.setAnchor(sname, "media", medX)

    Component.onCompleted: {
        ShellState.setAnchor(sname, "volume", volX);
        ShellState.setAnchor(sname, "brightness", briX);
        ShellState.setAnchor(sname, "network", netX);
        ShellState.setAnchor(sname, "battery", battX);
        ShellState.setAnchor(sname, "bluetooth", btX);
        ShellState.setAnchor(sname, "clock", clkX);
        ShellState.setAnchor(sname, "media", medX);
        ShellState.setAnchor(sname, "window", winX);
        ShellState.setAnchor(sname, "claude", claX);
    }

    Item {
        id: contentArea
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight
        anchors.leftMargin: 14
        anchors.rightMargin: 14

        RowLayout {
            id: leftRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

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

            FocusedApp { id: focusedApp }
            PrivacyWidget {}
            MediaWidget { id: mediaW }
        }

        RowLayout {
            id: centerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            DateWeatherWidget { id: clockW }
        }

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            ClaudeWidget { id: claudeW }
            TrayWidget {}
            AudioWidget { id: audioW }
            BacklightWidget { id: backlightW }
            NetworkWidget { id: netW }
            BluetoothWidget { id: btW }
            BatteryWidget { id: battW }
            CaffeineWidget {}
            NotifWidget {}
        }
    }
}
