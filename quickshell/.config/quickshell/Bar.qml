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

    Component.onCompleted: {
        ShellState.screenW = Qt.binding(() => bar.width);
        ShellState.volumeX = Qt.binding(() =>
            contentArea.x + rightRow.x + audioW.x + audioW.width / 2);
        ShellState.brightnessX = Qt.binding(() =>
            contentArea.x + rightRow.x + backlightW.x + backlightW.width / 2);
        ShellState.networkX = Qt.binding(() =>
            contentArea.x + rightRow.x + netW.x + netW.width / 2);
        ShellState.batteryX = Qt.binding(() =>
            contentArea.x + rightRow.x + battW.x + battW.width / 2);
        ShellState.mediaX = Qt.binding(() =>
            contentArea.x + leftRow.x + mediaW.x + mediaW.width / 2);
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

            WorkspaceDots {}
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
            BatteryWidget { id: battW }
            ClockWidget {}
            NotifWidget {}
        }
    }
}
