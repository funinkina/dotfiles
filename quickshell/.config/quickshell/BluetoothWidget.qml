import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bar bluetooth: icon (dim when off) + battery of the connected device.
Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight
    visible: Bluetooth.defaultAdapter !== null

    readonly property bool on: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var connectedDev:
        Bluetooth.devices.values.find(d => d.connected) ?? null
    readonly property int devBattery: {
        const d = connectedDev;
        if (!d || !d.batteryAvailable)
            return -1;
        return d.battery <= 1 ? Math.round(d.battery * 100) : Math.round(d.battery);
    }

    HoverBg {
        active: ShellState.isOpen("bluetooth", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ColorIcon {
            name: "bluetooth-symbolic"
            size: 16
            tint: root.on
                ? (root.connectedDev ? Theme.fg : Theme.dim)
                : Theme.faint
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: root.devBattery >= 0
            text: root.devBattery + "%"
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("bluetooth", QsWindow.window?.screen?.name ?? "")
    }
}
