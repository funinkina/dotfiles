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

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: NiriService.workspaces

            Rectangle {
                required property var modelData
                width: 24
                height: 20
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.is_active ? Theme.accent
                    : modelData.is_urgent ? Theme.urgent
                    : chipMouse.containsMouse ? "#2a2a2a" : "#161616"

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.idx
                    color: modelData.is_active ? "#000000"
                        : modelData.is_urgent ? "#000000" : Theme.muted
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
