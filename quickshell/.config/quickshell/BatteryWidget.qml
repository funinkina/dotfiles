import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.UPower

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    readonly property var dev: UPower.displayDevice
    readonly property int percent: Math.round((dev?.percentage ?? 0) * 100)
    readonly property bool charging: dev
        ? dev.state === UPowerDeviceState.Charging
          || dev.state === UPowerDeviceState.PendingCharge
          || dev.state === UPowerDeviceState.FullyCharged
        : false
    readonly property bool low: percent <= 10 && !charging
    readonly property color tone: low ? Theme.urgent : Theme.fg

    visible: dev?.isLaptopBattery ?? false

    HoverBg {
        active: ShellState.isOpen("battery", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        // Current power profile
        ColorIcon {
            name: PowerProfiles.profile === PowerProfile.PowerSaver
                ? "power-profile-power-saver-symbolic"
                : PowerProfiles.profile === PowerProfile.Performance
                    ? "power-profile-performance-symbolic"
                    : "power-profile-balanced-symbolic"
            size: 15
            Layout.alignment: Qt.AlignVCenter
        }

        // Drawn battery: outline + charge-level fill + bolt when charging
        Item {
            implicitWidth: 25
            implicitHeight: 12
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: body
                width: 22
                height: 12
                radius: 3
                color: "transparent"
                border.color: root.tone
                border.width: 1

                Rectangle {
                    x: 2
                    y: 2
                    height: 8
                    width: Math.max(1, 18 * root.percent / 100)
                    // Kept under the shell's radius so the fill nests inside
                    // the outline instead of tracing it.
                    radius: 2
                    color: root.tone
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            Rectangle {
                x: 23
                y: 3.5
                width: 2
                height: 5
                radius: 1
                color: root.tone
            }

            Canvas {
                visible: root.charging
                width: 12
                height: 16
                anchors.centerIn: body
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(1.5, 1.6);
                    ctx.fillStyle = "#168e1c";
                    ctx.beginPath();
                    ctx.moveTo(5, 0);
                    ctx.lineTo(0, 5.5);
                    ctx.lineTo(3.2, 5.5);
                    ctx.lineTo(2.6, 10);
                    ctx.lineTo(8, 4.2);
                    ctx.lineTo(4.4, 4.2);
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        Text {
            text: root.percent + "%"
            color: root.tone
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: root.percent <= 25 && !root.charging
                ? Font.Bold : Font.Normal
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
        onClicked: ShellState.togglePanel("battery", QsWindow.window?.screen?.name ?? "")
    }
}
