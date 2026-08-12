import QtQuick

// Slider row shared by the output and microphone sections:
// icon (click to mute) · draggable track · percent.
Item {
    id: root
    property var node
    property bool mic: false

    readonly property real vol: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    height: 22

    function setVol(v) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    ColorIcon {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: 16
        name: root.mic
            ? (root.muted ? "microphone-sensitivity-muted-symbolic"
                : root.vol > 0.66 ? "microphone-sensitivity-high-symbolic"
                : root.vol > 0.33 ? "microphone-sensitivity-medium-symbolic"
                : "microphone-sensitivity-low-symbolic")
            : (root.muted ? "audio-volume-muted-symbolic"
                : root.vol > 0.66 ? "audio-volume-high-symbolic"
                : root.vol > 0.33 ? "audio-volume-medium-symbolic"
                : "audio-volume-low-symbolic")
        tint: root.muted ? Theme.faint : Theme.fg

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.vol * 100) + "%"
        color: root.muted ? Theme.faint : Theme.fg
        font.family: Theme.uiFont
        font.pixelSize: 12
    }

    Item {
        id: track
        anchors.left: icon.right
        anchors.right: pct.left
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: parent.height

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: trackMouse.containsMouse || trackMouse.pressed ? 7 : 5
            radius: height / 2
            color: Theme.press
            Behavior on height { NumberAnimation { duration: 100 } }

            Rectangle {
                width: parent.width * Math.min(1, root.vol)
                height: parent.height
                radius: parent.radius
                color: root.muted ? Theme.muted : Theme.accent
            }
        }

        // Drag knob, shown while hovering or dragging
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width,
                parent.width * Math.min(1, root.vol) - width / 2))
            width: 13
            height: 13
            radius: 6.5
            color: Theme.accent
            border.color: Theme.bg
            border.width: 2
            opacity: trackMouse.containsMouse || trackMouse.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.setVol(mouse.x / width)
            onPositionChanged: mouse => {
                if (pressed)
                    root.setVol(mouse.x / width);
            }
            onWheel: wheel => root.setVol(
                root.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
}
