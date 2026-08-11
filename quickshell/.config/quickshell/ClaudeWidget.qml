import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    readonly property real pct: ClaudeService.weekPct

    HoverBg {
        active: ShellState.isOpen("claude", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Image {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            sourceSize: Qt.size(30, 30)
            source: Qt.resolvedUrl("assets/claude.svg")
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            implicitWidth: 42
            implicitHeight: 5
            radius: 2.5
            color: Theme.press
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                width: parent.width * Math.min(1, root.pct / 100)
                height: parent.height
                radius: parent.radius
                color: root.pct >= 90 ? Theme.urgent : Theme.accent
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        Text {
            text: ClaudeService.ok ? Math.round(root.pct) + "%" : "—"
            color: root.pct >= 90 ? Theme.urgent : Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("claude", QsWindow.window?.screen?.name ?? "")
    }
}
