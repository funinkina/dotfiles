pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Camera / microphone / screenshare usage, pushed by the PipeWire
// registry monitor (event-driven, no polling).
Singleton {
    id: root

    property bool mic: false
    property bool cam: false
    // Screencasts come authoritatively from niri's IPC, not pipewire heuristics
    readonly property bool screen: NiriService.casts.length > 0

    Process {
        command: ["python3",
            "/home/funinkina/.config/quickshell/scripts/privacy-monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let s;
                try { s = JSON.parse(data); } catch (e) { return; }
                root.mic = s.mic;
                root.cam = s.cam;
            }
        }
    }
}
