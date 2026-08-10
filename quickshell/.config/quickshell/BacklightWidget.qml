import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    readonly property int current: parseInt(curFile.text()) || 0
    readonly property int max: parseInt(maxFile.text()) || 1
    readonly property int percent: Math.round(current / max * 100)

    FileView {
        id: curFile
        path: "/sys/class/backlight/intel_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: maxFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    HoverBg {
        active: ShellState.isOpen("display", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ColorIcon {
            name: "display-brightness-symbolic"
            size: 16
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
        onClicked: ShellState.togglePanel("display", QsWindow.window?.screen?.name ?? "")
        onWheel: wheel => {
            Quickshell.execDetached(["brightnessctl", "set",
                wheel.angleDelta.y > 0 ? "5%+" : "5%-"]);
        }
    }
}
