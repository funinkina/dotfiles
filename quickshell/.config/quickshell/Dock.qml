import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Left-edge dock: pinned apps on top, running-but-unpinned windows below the
// hairline, the workspace map and the launcher button at the bottom.
//
// Pinned icons drag to reorder and right-click for a menu. The menu needs far
// more room than the 52px strip, so while it is open the surface widens to the
// whole screen — the exclusive zone stays at the strip width, so nothing else
// moves, and a click anywhere off the menu dismisses it.
PanelWindow {
    id: dock
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dock"

    visible: ShellState.dockVisible

    readonly property string sname: screen?.name ?? ""

    anchors { left: true; top: true; bottom: true }
    implicitWidth: menu.open ? (screen?.width ?? 1920) : Theme.dockWidth
    exclusiveZone: Theme.dockWidth
    color: "transparent"

    // Input is confined to the strip unless the menu is up, so the widened
    // surface never swallows clicks meant for the desktop.
    mask: menu.open ? null : stripRegion
    Region {
        id: stripRegion
        width: Theme.dockWidth
        height: dock.height
    }

    readonly property var wins:
        Object.values(NiriService.windows).sort((a, b) => a.id - b.id)

    readonly property var extraWins:
        wins.filter(w => !AppService.pinOwning(w))

    // Pinned slot pitch: the 44px button plus the 2px gap that used to come
    // from the column spacing. Drag maths needs one number for both.
    readonly property int itemH: 46

    property int dragIndex: -1
    property int dropIndex: -1
    property real dragY: 0
    property real dragOffset: 0

    function beginDrag(i, offset) {
        dragOffset = offset;
        dragIndex = i;
        dropIndex = i;
        dragY = i * itemH;
    }

    // `pointerY` is in pinArea coordinates, so it stays put while the tile
    // under the cursor moves with it.
    function updateDrag(pointerY) {
        dragY = pointerY - dragOffset;
        dropIndex = Math.max(0, Math.min(AppService.pinned.length - 1,
            Math.round(dragY / itemH)));
    }

    function endDrag() {
        const from = dragIndex, to = dropIndex;
        // Cleared before the model changes: the slot bindings below read
        // dragIndex, and the Repeater rebuilds the moment pinned is reassigned.
        dragIndex = -1;
        dropIndex = -1;
        if (from >= 0 && to >= 0 && from !== to)
            AppService.move(from, to);
    }

    component DockButton: Item {
        id: btn
        property string iconName
        property bool running: false
        property bool focused: false
        property bool draggable: false
        property bool dragging: false

        signal triggered()
        signal menuRequested()
        signal dragBegan(real grabOffset)
        signal dragMoved(real pointerY)
        signal dragEnded()

        width: Theme.dockWidth
        height: 44
        z: dragging ? 2 : 1

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: Theme.radius
            color: btn.dragging ? Theme.press
                : btnMouse.pressed ? Theme.press
                : btnMouse.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: btn.focused ? 22 : btnMouse.containsMouse ? 10 : btn.running ? 5 : 0
            color: btn.focused || btnMouse.containsMouse ? Theme.accent : Theme.muted
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: 34
            source: Quickshell.iconPath(btn.iconName, "application-x-executable")
            scale: btn.dragging ? 1.15
                : btnMouse.pressed ? 0.9
                : btnMouse.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            // Pointer position in the parent's coordinates. Reading it through
            // btn.y cancels out the tile moving under the cursor mid-drag,
            // which a raw mouse.y would feed back into itself.
            function pointer(mouse) { return btn.y + mouse.y; }

            property real pressAt: 0
            property bool moved: false

            onPressed: mouse => {
                moved = false;
                pressAt = pointer(mouse);
            }

            onPositionChanged: mouse => {
                if (!btn.draggable || !(pressedButtons & Qt.LeftButton))
                    return;
                const p = pointer(mouse);
                if (!moved) {
                    if (Math.abs(p - pressAt) < 6)
                        return;
                    moved = true;
                    btn.dragBegan(pressAt - btn.y);
                }
                btn.dragMoved(p);
            }

            onReleased: mouse => {
                if (moved) {
                    moved = false;
                    btn.dragEnded();
                } else if (mouse.button === Qt.RightButton) {
                    btn.menuRequested();
                } else {
                    btn.triggered();
                }
            }

            onCanceled: {
                if (moved) {
                    moved = false;
                    btn.dragEnded();
                }
            }
        }
    }

    // Fixed-width strip: everything visible lives in here so the contents
    // don't recentre when the window widens for the menu.
    Item {
        id: strip
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Theme.dockWidth

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter

            // Absolute positioning, not a Column: reordering is a matter of
            // which slot each tile animates to, and the dragged one has to sit
            // outside the layout entirely.
            Item {
                id: pinArea
                width: Theme.dockWidth
                height: AppService.pinned.length * dock.itemH

                Repeater {
                    model: AppService.pinned

                    DockButton {
                        id: pinBtn
                        required property var modelData
                        required property int index

                        readonly property var appWins: AppService.windowsFor(modelData)
                        readonly property var entry: NiriService.entryFor(modelData)

                        // Where this tile belongs once the in-flight drag is
                        // applied: drop the dragged item out of the list, then
                        // reinsert it at the hovered slot.
                        readonly property int slot: {
                            if (dock.dragIndex < 0)
                                return index;
                            if (index === dock.dragIndex)
                                return dock.dropIndex;
                            const i = index > dock.dragIndex ? index - 1 : index;
                            return i >= dock.dropIndex ? i + 1 : i;
                        }

                        iconName: entry?.icon ?? "application-x-executable"
                        running: appWins.length > 0
                        focused: appWins.some(w => w.id === NiriService.focusedWindowId)
                        draggable: true
                        dragging: dock.dragIndex === index

                        y: dragging ? dock.dragY : slot * dock.itemH
                        Behavior on y {
                            enabled: !pinBtn.dragging
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }

                        onTriggered: {
                            if (appWins.length > 0)
                                NiriService.dispatch(["focus-window",
                                    "--id", String(appWins[0].id)]);
                            else if (entry)
                                AppService.launchEntry(entry);
                        }
                        onMenuRequested: menu.show(modelData, Theme.dockWidth + 6,
                            mapToItem(null, 0, 0).y)
                        onDragBegan: offset => dock.beginDrag(index, offset)
                        onDragMoved: p => dock.updateDrag(p)
                        onDragEnded: dock.endDrag()
                    }
                }
            }

            Item {
                width: Theme.dockWidth
                height: 9
                visible: dock.extraWins.length > 0
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 1
                    color: Theme.line
                }
            }

            Column {
                spacing: 2

                Repeater {
                    model: dock.extraWins

                    DockButton {
                        required property var modelData
                        // Pin and menu act on the desktop entry when the
                        // window's app_id resolves to one, so an app pinned
                        // from here matches the ids already in the list.
                        readonly property string appId: {
                            const raw = modelData.app_id ?? "";
                            return NiriService.entryFor(raw)?.id ?? raw;
                        }

                        iconName: NiriService.appInfo(modelData).icon
                        running: true
                        focused: modelData.id === NiriService.focusedWindowId

                        onTriggered: NiriService.dispatch(
                            ["focus-window", "--id", String(modelData.id)])
                        onMenuRequested: menu.show(appId, Theme.dockWidth + 6,
                            mapToItem(null, 0, 0).y)
                    }
                }
            }
        }

        WorkspaceMap {
            anchors.bottom: launcherBtn.top
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            screenName: dock.sname
            aspect: dock.screen ? dock.screen.height / dock.screen.width : 0.625
        }

        Item {
            id: launcherBtn
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dockWidth
            height: 36

            readonly property bool active: ShellState.isOpen("launcher", dock.sname)

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                radius: Theme.radius
                color: launcherMouse.pressed || launcherBtn.active ? Theme.press
                    : launcherMouse.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            ColorIcon {
                anchors.centerIn: parent
                name: "view-app-grid-symbolic"
                size: 26
                tint: launcherMouse.containsMouse || launcherBtn.active
                    ? Theme.accent : Theme.muted
            }

            MouseArea {
                id: launcherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.togglePanel("launcher", dock.sname)
            }
        }
    }

    AppMenu {
        id: menu
        anchors.fill: parent
        output: dock.sname
    }
}
