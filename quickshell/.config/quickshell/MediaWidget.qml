import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Now playing: [play/pause button] Title ∙ Artist
Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    visible: player !== null && title !== ""

    readonly property var player: {
        const list = Mpris.players.values;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? list.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    HoverBg {}

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 8

        ColorIcon {
            name: root.playing
                ? "media-playback-pause-symbolic"
                : "media-playback-start-symbolic"
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
            text: "∙ " + root.artist
            visible: root.artist !== ""
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            Layout.maximumWidth: 160
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        onClicked: ShellState.togglePanel("media")
    }
}
