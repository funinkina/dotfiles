import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick

// Now-playing popout: art, title, artist — album, seek bar, transport controls.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-media"

    visible: ShellState.openPanel === "media"

    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight + 8
        left: ShellState.mediaX < 0 ? Theme.dockWidth + 8
            : Math.max(Theme.dockWidth + 8,
                Math.min(ShellState.mediaX - implicitWidth / 2,
                    ShellState.screenW - implicitWidth - 8))
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420
    implicitHeight: col.implicitHeight + 30
    color: "transparent"

    readonly property var player: {
        const list = Mpris.players.values;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? list.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property real len: player?.length ?? 0

    property real pos: 0

    function syncPos() { pos = player?.position ?? 0; }
    onVisibleChanged: if (visible) syncPos()
    onPlayerChanged: syncPos()

    Timer {
        interval: 1000
        running: panel.visible && panel.playing
        repeat: true
        onTriggered: panel.syncPos()
    }

    function fmt(s) {
        s = Math.max(0, Math.round(s));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 6

        Row {
            spacing: 16
            width: parent.width

            ClippingRectangle {
                width: 78
                height: 78
                radius: 8
                color: "#161616"

                Image {
                    anchors.fill: parent
                    source: panel.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 94
                spacing: 6

                Text {
                    width: parent.width
                    text: panel.player?.trackTitle ?? ""
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: {
                        const a = panel.player?.trackArtist ?? "";
                        const al = panel.player?.trackAlbum ?? "";
                        return al ? `${a} — ${al}` : a;
                    }
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }
        }

        Item { width: 1; height: 6 }

        Item {
            width: parent.width
            height: 13

            Text {
                anchors.left: parent.left
                text: panel.fmt(panel.pos)
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                text: panel.fmt(panel.len)
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }

        Item {
            width: parent.width
            height: 10

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: "#2e2e2e"

                Rectangle {
                    width: panel.len > 0
                        ? track.width * Math.min(1, panel.pos / panel.len) : 0
                    height: parent.height
                    radius: 2
                    color: Theme.fg
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    if (panel.player?.canSeek && panel.len > 0) {
                        panel.player.position = (mouse.x / width) * panel.len;
                        panel.syncPos();
                    }
                }
            }
        }

        Item { width: 1; height: 8 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 40

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "media-playlist-shuffle-symbolic"
                size: 18
                tint: panel.player?.shuffle ? Theme.fg : Theme.faint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: {
                        if (panel.player?.shuffleSupported)
                            panel.player.shuffle = !panel.player.shuffle;
                    }
                }
            }

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "media-skip-backward-symbolic"
                size: 22
                tint: panel.player?.canGoPrevious ? Theme.fg : Theme.faint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: panel.player?.previous()
                }
            }

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: panel.playing
                    ? "media-playback-pause-symbolic"
                    : "media-playback-start-symbolic"
                size: 28
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: panel.player?.togglePlaying()
                }
            }

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "media-skip-forward-symbolic"
                size: 22
                tint: panel.player?.canGoNext ? Theme.fg : Theme.faint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: panel.player?.next()
                }
            }

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: panel.player?.loopState === MprisLoopState.Track
                    ? "media-playlist-repeat-song-symbolic"
                    : "media-playlist-repeat-symbolic"
                size: 18
                tint: panel.player?.loopState !== MprisLoopState.None
                    ? Theme.fg : Theme.faint
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: {
                        const p = panel.player;
                        if (!p?.loopSupported)
                            return;
                        p.loopState = p.loopState === MprisLoopState.None
                            ? MprisLoopState.Playlist
                            : p.loopState === MprisLoopState.Playlist
                                ? MprisLoopState.Track : MprisLoopState.None;
                    }
                }
            }
        }
    }
}
