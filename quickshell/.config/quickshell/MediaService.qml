pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The player the shell acts on: whatever is playing, else whatever is paused.
Singleton {
    id: root

    readonly property var player: {
        const list = Mpris.players.values;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? list.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
}
