import Quickshell
import Quickshell.Wayland
import QtQuick

// Custom-styled tray menu (replaces ugly native platform menus).
// Renders the item's DBus menu; submenus drill down with a Back row.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-traymenu"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "traymenu" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.traymenu ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 260
    implicitHeight: Math.min(520, flick.contentHeight + 16)
    color: "transparent"

    // Submenu navigation stack; top of stack (or the root handle) is shown
    property var stack: []
    readonly property var currentMenu: stack.length > 0
        ? stack[stack.length - 1] : ShellState.trayMenuHandle

    onVisibleChanged: if (visible) stack = []

    QsMenuOpener {
        id: opener
        menu: panel.currentMenu
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width

            // Back row while inside a submenu
            Rectangle {
                visible: panel.stack.length > 0
                width: col.width
                height: 30
                color: backMouse.containsMouse ? "#1f1f1f" : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹ Back"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.stack = panel.stack.slice(0, -1)
                }
            }

            Repeater {
                model: opener.children

                Item {
                    id: entryItem
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 9 : 30

                    Rectangle {
                        visible: entryItem.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.faint
                    }

                    Rectangle {
                        visible: !entryItem.modelData.isSeparator
                        anchors.fill: parent
                        color: entryMouse.containsMouse && entryItem.modelData.enabled
                            ? "#1f1f1f" : "transparent"

                        // Checkbox / radio state
                        ColorIcon {
                            id: checkIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            name: "object-select-symbolic"
                            size: 13
                            visible: entryItem.modelData.checkState === Qt.Checked
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: entryItem.modelData.checkState !== undefined
                                && entryItem.modelData.buttonType !== 0 ? 28 : 10
                            anchors.right: subArrow.visible ? subArrow.left : parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: entryItem.modelData.text
                            color: entryItem.modelData.enabled ? Theme.fg : Theme.faint
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            id: subArrow
                            visible: entryItem.modelData.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryItem.modelData.enabled
                            onClicked: {
                                const e = entryItem.modelData;
                                if (e.hasChildren) {
                                    panel.stack = panel.stack.concat([e]);
                                } else {
                                    e.triggered();
                                    ShellState.closePanels();
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: opener.children.values.length === 0
                leftPadding: 10
                topPadding: 6
                bottomPadding: 6
                text: "Empty menu"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
