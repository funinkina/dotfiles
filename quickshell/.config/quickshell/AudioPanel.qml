import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

// Audio popout: volume slider + selectable output devices.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-audio"

    visible: ShellState.openPanel === "audio"

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: ShellState.volumeX < 0 ? 16
            : Math.max(8, ShellState.screenW - ShellState.volumeX - implicitWidth / 2)
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    readonly property var sinks:
        Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    PwObjectTracker { objects: panel.sinks }

    function sinkName(n) {
        return n.nickname || n.description || n.name;
    }

    function setVol(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6

        Text {
            text: "Volume"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 2 }

        // Slider row: icon · track · %
        Item {
            width: parent.width
            height: 22

            ColorIcon {
                id: volIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: 16
                name: panel.muted ? "audio-volume-muted-symbolic"
                    : panel.vol > 0.66 ? "audio-volume-high-symbolic"
                    : panel.vol > 0.33 ? "audio-volume-medium-symbolic"
                    : "audio-volume-low-symbolic"
                tint: panel.muted ? Theme.faint : Theme.fg

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        if (panel.sink?.audio)
                            panel.sink.audio.muted = !panel.sink.audio.muted;
                    }
                }
            }

            Text {
                id: volPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(panel.vol * 100) + "%"
                color: panel.muted ? Theme.faint : Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 12
            }

            Item {
                id: track
                anchors.left: volIcon.right
                anchors.right: volPct.left
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: parent.height

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    color: Theme.faint

                    Rectangle {
                        width: parent.width * Math.min(1, panel.vol)
                        height: parent.height
                        color: panel.muted ? Theme.muted : Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => panel.setVol(mouse.x / width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            panel.setVol(mouse.x / width);
                    }
                    onWheel: wheel => panel.setVol(
                        panel.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }

        Item { width: 1; height: 10 }

        Text {
            text: "Output device"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        Item { width: 1; height: 2 }

        Repeater {
            model: panel.sinks

            Rectangle {
                id: row
                required property var modelData
                readonly property bool active:
                    modelData.id === Pipewire.defaultAudioSink?.id
                width: col.width
                height: 34
                color: rowMouse.containsMouse ? "#1a1a1a" : "transparent"

                Rectangle {
                    visible: row.active
                    anchors.left: parent.left
                    width: 3
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: checkIcon.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.sinkName(row.modelData)
                    color: row.active ? Theme.fg : Theme.dim
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.weight: row.active ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }

                ColorIcon {
                    id: checkIcon
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "object-select-symbolic"
                    size: 14
                    tint: Theme.fg
                    visible: row.active
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Pipewire.preferredDefaultAudioSink = row.modelData
                }
            }
        }

        Text {
            visible: panel.sinks.length === 0
            text: "No output devices"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
}
