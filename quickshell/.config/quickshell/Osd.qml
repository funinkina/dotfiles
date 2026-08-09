import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Volume/brightness OSD that slides out from under the top bar.
PanelWindow {
    id: osd
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-osd"

    // Center under the icon whose value is being shown
    readonly property real anchorX: mode === "brightness"
        ? ShellState.brightnessX : ShellState.volumeX

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight
        right: anchorX < 0 ? 16
            : Math.max(8, ShellState.screenW - anchorX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 230
    implicitHeight: 44
    color: "transparent"

    // Click-through
    mask: Region {}

    visible: false

    property bool shown: false
    property bool ready: false
    property string mode: "volume"
    property real value: 0

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    FileView {
        id: bright
        path: "/sys/class/backlight/intel_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: brightMax
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    readonly property real brightVal:
        (parseInt(bright.text()) || 0) / (parseInt(brightMax.text()) || 1)

    // `ready` suppresses the OSD for initial value loads at startup
    onVolChanged: if (ready) show("volume", vol)
    onMutedChanged: if (ready) show("volume", vol)
    onBrightValChanged: if (ready) show("brightness", brightVal)

    Connections {
        target: ShellState
        function onOsdRequested(mode) {
            osd.show(mode, mode === "brightness" ? osd.brightVal : osd.vol);
        }
    }

    function show(m, v) {
        mode = m;
        value = v;
        visible = true;
        shown = true;
        hideTimer.restart();
    }

    Timer { id: readyTimer; interval: 1500; running: true; onTriggered: osd.ready = true }
    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: {
            osd.shown = false;
            unmapTimer.restart();
        }
    }
    Timer { id: unmapTimer; interval: 220; onTriggered: if (!osd.shown) osd.visible = false }

    Rectangle {
        id: content
        width: parent.width
        height: parent.height
        y: osd.shown ? 0 : -height
        opacity: osd.shown ? 1 : 0
        color: Theme.bg

        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Row {
            anchors.centerIn: parent
            spacing: 12

            ColorIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                name: osd.mode === "brightness" ? "display-brightness-symbolic"
                    : osd.muted ? "audio-volume-muted-symbolic"
                    : osd.value > 0.66 ? "audio-volume-high-symbolic"
                    : osd.value > 0.33 ? "audio-volume-medium-symbolic"
                    : "audio-volume-low-symbolic"
                tint: osd.mode === "volume" && osd.muted ? Theme.faint : Theme.fg
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 148
                height: 5
                color: Theme.faint

                Rectangle {
                    width: parent.width * Math.min(1, osd.value)
                    height: parent.height
                    color: osd.mode === "volume" && osd.muted ? Theme.muted : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
