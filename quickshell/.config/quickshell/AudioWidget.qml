import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    HoverBg {
        active: ShellState.isOpen("audio", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        ColorIcon {
            name: root.muted ? "audio-volume-muted-symbolic"
                : root.vol > 0.66 ? "audio-volume-high-symbolic"
                : root.vol > 0.33 ? "audio-volume-medium-symbolic"
                : "audio-volume-low-symbolic"
            tint: root.muted ? Theme.faint : Theme.fg
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                ShellState.togglePanel("audio", QsWindow.window?.screen?.name ?? "");
            }
        }
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume =
                Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
