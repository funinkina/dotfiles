import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

// Audio popout: output and microphone, each a volume slider + device picker.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-audio"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "audio" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.volume ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    // Bind every non-stream node, then classify. `properties` is only
    // populated once a node is tracked, so filtering on media.class first
    // would be circular — it would match only nodes something else had
    // already bound, silently hiding the rest.
    readonly property var devices: Pipewire.nodes.values.filter(n => !n.isStream)
    PwObjectTracker { objects: panel.devices }

    readonly property var sinks: devices.filter(n => n.isSink)
    // Not `!isSink`: that also catches pipewire's internal nodes
    // (Dummy-Driver, Freewheel-Driver, Midi-Bridge) and the v4l2 camera.
    readonly property var sources: devices.filter(
        n => n.properties?.["media.class"] === "Audio/Source")

    PanelSurface { id: surf }

    component Heading: Text {
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6
        opacity: surf.opacity

        Heading { text: "Volume" }

        Item { width: 1; height: 2 }

        AudioSlider {
            width: col.width
            node: Pipewire.defaultAudioSink
        }

        Item { width: 1; height: 10 }

        Heading { text: "Output device" }

        Item { width: 1; height: 2 }

        Repeater {
            model: panel.sinks

            AudioDeviceRow {
                required property var modelData
                width: col.width
                node: modelData
                active: modelData.id === Pipewire.defaultAudioSink?.id
                onChosen: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        Text {
            visible: panel.sinks.length === 0
            text: "No output devices"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Item { width: 1; height: 14 }

        Heading { text: "Microphone" }

        Item { width: 1; height: 2 }

        AudioSlider {
            width: col.width
            mic: true
            node: Pipewire.defaultAudioSource
        }

        Item { width: 1; height: 10 }

        Heading { text: "Input device" }

        Item { width: 1; height: 2 }

        Repeater {
            model: panel.sources

            AudioDeviceRow {
                required property var modelData
                width: col.width
                node: modelData
                active: modelData.id === Pipewire.defaultAudioSource?.id
                onChosen: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        Text {
            visible: panel.sources.length === 0
            text: "No input devices"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
}
