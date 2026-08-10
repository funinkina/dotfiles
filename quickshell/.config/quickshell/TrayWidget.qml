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

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate();
                    } else if (item.hasMenu) {
                        ShellState.openTrayMenu(item.menu,
                            trayItem.mapToItem(null, trayItem.width / 2, 0).x,
                            QsWindow.window?.screen?.name ?? "");
                    } else {
                        item.activate();
                    }
                }
            }
        }
    }
}
