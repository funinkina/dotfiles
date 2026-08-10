import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick

// Bluetooth popout: power toggle + paired devices with battery,
// connect/disconnect on click.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-bluetooth"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "bluetooth" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.bluetooth ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devs: Bluetooth.devices.values
        .filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected)
            || (a.name ?? "").localeCompare(b.name ?? ""))

    function devBattery(d) {
        if (!d.batteryAvailable)
            return -1;
        return d.battery <= 1 ? Math.round(d.battery * 100) : Math.round(d.battery);
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6
        opacity: surf.opacity

        // Header: label + on/off segmented toggle
        Item {
            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }

            Rectangle {
                id: toggle
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
                            readonly property bool active: panel.on === modelData.val
                            width: parent.width / 2
                            height: parent.height
                            color: active ? Theme.accent
                                : segMouse.pressed ? Theme.press
                                : segMouse.containsMouse ? Theme.hover : "transparent"

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
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (panel.adapter)
                                        panel.adapter.enabled = parent.modelData.val;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 6 }

        Text {
            visible: !panel.on
            text: "Bluetooth is off"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Repeater {
            model: panel.on ? panel.devs : []

            Rectangle {
                id: row
                required property var modelData
                readonly property int batt: panel.devBattery(modelData)
                width: col.width
                height: 40
                radius: Theme.radius
                color: rowMouse.pressed ? Theme.press
                    : rowMouse.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Rectangle {
                    visible: row.modelData.connected
                    anchors.left: parent.left
                    width: 3
                    height: 22
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                }

                ColorIcon {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: (row.modelData.icon || "bluetooth") + "-symbolic"
                    size: 16
                    tint: row.modelData.connected ? Theme.fg : Theme.muted
                }

                Column {
                    anchors.left: devIcon.right
                    anchors.leftMargin: 10
                    anchors.right: battText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.name || row.modelData.deviceName
                        color: row.modelData.connected ? Theme.fg : Theme.dim
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: {
                            const s = row.modelData.state;
                            if (s === BluetoothDeviceState.Connecting)
                                return "Connecting…";
                            if (s === BluetoothDeviceState.Disconnecting)
                                return "Disconnecting…";
                            return row.modelData.connected ? "Connected" : "Paired";
                        }
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                    }
                }

                Text {
                    id: battText
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.batt >= 0
                    text: row.batt + "%"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.connected)
                            row.modelData.disconnect();
                        else
                            row.modelData.connect();
                    }
                }
            }
        }

        Text {
            visible: panel.on && panel.devs.length === 0
            text: "No paired devices"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
}
