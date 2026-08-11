import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight
    visible: player !== null && title !== ""

    readonly property var player: MediaService.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    HoverBg {
        active: ShellState.isOpen("media", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        ColorIcon {
            name: "audio-x-generic-symbolic"
            size: 14
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.title
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.maximumWidth: 220
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: "∙"
            visible: root.artist !== ""
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.artist
            visible: root.artist !== ""
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.maximumWidth: 220
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.togglePanel("media", QsWindow.window?.screen?.name ?? "")
    }
}
