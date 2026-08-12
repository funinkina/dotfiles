import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: osd
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property string sname: screen?.name ?? ""
    readonly property real anchorX: (mode === "brightness"
        ? ShellState.anchorMap[sname]?.brightness
        : ShellState.anchorMap[sname]?.volume) ?? -1

    readonly property bool fullscreen:
        NiriService.isFullscreen(sname, screen?.height ?? 0)

    anchors { top: true; right: !fullscreen }
    margins {
        top: fullscreen ? 12 : Theme.barHeight + 8
        right: fullscreen ? 0
            : anchorX < 0 ? 16
            : Math.max(8, (screen?.width ?? 1920) - anchorX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 286
    implicitHeight: 68
    color: "transparent"

    mask: Region {}

    visible: false

    property bool shown: false
    property bool ready: false
    property string mode: "volume"
    property real value: 0

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property string deviceName: mode === "brightness"
        ? (osd.screen?.name ?? "Display")
        : (sink?.nickname || sink?.description || "Audio")

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

    onVolChanged: { volAt = Date.now(); if (ready) show("volume", vol); }
    onMutedChanged: if (ready) show("volume", vol)
    onBrightValChanged: { brightAt = Date.now(); if (ready) show("brightness", brightVal); }

    Connections {
        target: ShellState
        function onOsdRequested(mode) {
            osd.show(mode, mode === "brightness" ? osd.brightVal : osd.vol);
        }
        function onOsdStepped(mode, dir) {
            const movedAt = mode === "brightness" ? osd.brightAt : osd.volAt;
            if (Date.now() - movedAt < 150)
                return; 
            osd.show(mode, mode === "brightness" ? osd.brightVal : osd.vol);
            osd.nudge(dir === "up" ? 1 : -1);
        }
        function onOpenPanelChanged() {
            if (osd.shown && (ShellState.openPanel === "audio"
                    || ShellState.openPanel === "display")) {
                osd.shown = false;
                hideTimer.stop();
                unmapTimer.restart();
            }
        }
    }

    property real volAt: 0
    property real brightAt: 0

    function nudge(dir) {
        nudgeAnim.dir = dir;
        nudgeAnim.restart();
    }

    SequentialAnimation {
        id: nudgeAnim
        property int dir: 1
        NumberAnimation {
            target: content; property: "nudgeX"
            to: nudgeAnim.dir * 8; duration: 90; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: content; property: "nudgeX"
            to: nudgeAnim.dir * -3; duration: 90
        }
        NumberAnimation {
            target: content; property: "nudgeX"
            to: 0; duration: 120; easing.type: Easing.OutCubic
        }
    }

    function show(m, v) {
        if (ShellState.openPanel === "audio" || ShellState.openPanel === "display")
            return;
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
        property real nudgeX: 0
        width: 270
        height: parent.height
        x: (osd.width - width) / 2 + nudgeX
        y: osd.shown ? 0 : -height
        opacity: osd.shown ? 1 : 0
        color: Theme.bg
        radius: Theme.panelRadius
        border.color: Theme.border
        border.width: 1

        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 9

            Text {
                width: parent.width
                text: osd.deviceName
                color: Theme.fg
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Item {
                width: parent.width
                height: 18

                ColorIcon {
                    id: osdIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    name: osd.mode === "brightness" ? "display-brightness-symbolic"
                        : osd.muted ? "audio-volume-muted-symbolic"
                        : osd.value > 0.66 ? "audio-volume-high-symbolic"
                        : osd.value > 0.33 ? "audio-volume-medium-symbolic"
                        : "audio-volume-low-symbolic"
                    tint: osd.mode === "volume" && osd.muted ? Theme.faint : Theme.fg
                }

                Text {
                    id: osdPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(osd.value * 100) + "%"
                    color: osd.mode === "volume" && osd.muted ? Theme.faint : Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                Rectangle {
                    anchors.left: osdIcon.right
                    anchors.right: osdPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 2.5
                    color: Theme.press

                    Rectangle {
                        width: parent.width * Math.min(1, osd.value)
                        height: parent.height
                        radius: parent.radius
                        color: osd.mode === "volume" && osd.muted ? Theme.muted : Theme.accent
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
