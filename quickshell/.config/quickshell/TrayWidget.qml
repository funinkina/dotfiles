import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 10
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property var modelData
            implicitWidth: 16
            implicitHeight: Theme.barHeight
            Layout.alignment: Qt.AlignVCenter

            HoverBg {
                anchors.leftMargin: -5
                anchors.rightMargin: -5
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu)
                        menuAnchor.open();
                    else
                        trayItem.modelData.activate();
                }
            }
        }
    }
}
