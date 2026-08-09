import QtQuick

Item {
    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.barHeight

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            NiriService.dispatch([wheel.angleDelta.y > 0
                ? "focus-workspace-up" : "focus-workspace-down"]);
        }
    }

    // Boxy segmented row: shared 1px borders, no gaps, no rounding
    Rectangle {
        id: row
        anchors.centerIn: parent
        implicitWidth: cells.implicitWidth + 2
        implicitHeight: 22
        color: "transparent"
        border.color: Theme.faint
        border.width: 1

        Row {
            id: cells
            anchors.fill: parent
            anchors.margins: 1

            Repeater {
                model: NiriService.workspaces.filter(w => w.name !== "hidden")

                Rectangle {
                    required property var modelData
                    required property int index
                    width: 26
                    height: parent.height
                    color: modelData.is_active ? Theme.accent
                        : modelData.is_urgent ? Theme.urgent
                        : chipMouse.containsMouse ? "#1f1f1f" : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        visible: parent.index > 0
                        anchors.left: parent.left
                        width: 1
                        height: parent.height
                        color: Theme.faint
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.idx
                        color: modelData.is_active || modelData.is_urgent
                            ? "#000000" : Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: NiriService.dispatch(["focus-workspace", String(modelData.idx)])
                    }
                }
            }
        }
    }
}
