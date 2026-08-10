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
                pressed: trayMouse.pressed
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate();
                    } else if (item.hasMenu) {
                        item.display(QsWindow.window,
                            trayItem.mapToItem(null, 0, 0).x, Theme.barHeight);
                    } else {
                        item.activate();
                    }
                }
            }
        }
    }
}
