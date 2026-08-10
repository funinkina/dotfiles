import QtQuick
import Quickshell.Widgets

// Now playing on the lock screen: art, track, and transport. No seek bar —
// this is for glancing and skipping, not scrubbing. Sits bare on the
// wallpaper under the clock, so it carries no card of its own.
Item {
    id: root
    readonly property var player: MediaService.player
    readonly property string art: player?.trackArtUrl ?? ""

    visible: MediaService.active
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 14

        // Dropped entirely when the track has no art, rather than leaving a
        // bare square floating on the wallpaper.
        ClippingRectangle {
            visible: root.art !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            height: 70
            radius: Theme.radius
            color: Theme.surface

            Image {
                anchors.fill: parent
                source: root.art
                fillMode: Image.PreserveAspectCrop
            }
        }

        Column {
            // Hug the content up to a cap, so a short track title doesn't
            // leave the block sitting off-centre under the clock.
            width: Math.min(260, Math.max(title.implicitWidth, artist.implicitWidth,
                                          controls.implicitWidth))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                id: title
                width: parent.width
                text: root.player?.trackTitle ?? ""
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: artist
                width: parent.width
                text: root.player?.trackArtist ?? ""
                visible: text !== ""
                color: Theme.dim
                font.family: Theme.uiFont
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Item { width: 1; height: 6 }

            Row {
                id: controls
                spacing: 22

                IconButton {
                    icon: "media-skip-backward-symbolic"
                    size: 20
                    enabled: root.player?.canGoPrevious ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.player?.previous()
                }

                IconButton {
                    icon: MediaService.playing
                        ? "media-playback-pause-symbolic"
                        : "media-playback-start-symbolic"
                    size: 26
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    icon: "media-skip-forward-symbolic"
                    size: 20
                    enabled: root.player?.canGoNext ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.player?.next()
                }
            }
        }
    }
}
