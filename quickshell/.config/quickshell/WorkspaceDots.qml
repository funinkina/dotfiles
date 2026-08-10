import QtQuick

// Both of niri's axes in one control. Vertically: one dash per workspace, top
// to bottom, matching the way workspaces stack. Horizontally: the active dash
// expands to full length and splits into the columns of that workspace's
// scrolling layout, sized to their real widths, with the focused one lit.
//
// The active dash is always the same total length, so the bar never reflows
// as windows come and go — only its internal division changes.
//
// It deliberately draws no viewport rectangle. Niri 26.04 never populates
// `tile_pos_in_workspace_view`, and with center-focused-column "never" the
// scroll offset depends on history the IPC won't report, so the visible edges
// would be guesswork. Everything drawn here is exact.
Item {
    id: root

    // Connector name of the monitor this bar lives on (e.g. "eDP-1")
    property string screenName: ""

    readonly property real activeW: 48   // length of the expanded active dash
    readonly property real colGap: 2
    readonly property real padX: 6

    // Sorted, because with a vertical stack the order carries the meaning.
    readonly property var list: NiriService.workspaces
        .filter(w => w.name !== "hidden"
            && (screenName === "" || w.output === screenName))
        .sort((a, b) => a.idx - b.idx)

    // Laid out by pitch rather than fixed gaps, so the stack always fits the
    // bar however many workspaces niri has spun up.
    readonly property real avail: Theme.barHeight - 12
    readonly property real pitch: list.length > 0 ? avail / list.length : avail

    readonly property var activeWorkspaceId: {
        const ws = list.find(w => w.is_active);
        return ws ? ws.id : null;
    }

    // Columns of the active workspace, left to right. A column's width is the
    // widest tile in it; tiles stacked in a column share that width.
    readonly property var cols: {
        const wsId = root.activeWorkspaceId;
        if (wsId === null)
            return [];
        const byCol = {};
        const wins = NiriService.windows;
        for (const id in wins) {
            const w = wins[id];
            if (w.workspace_id !== wsId || w.is_floating)
                continue;
            const layout = w.layout;
            if (!layout || !layout.pos_in_scrolling_layout)
                continue;
            const ci = layout.pos_in_scrolling_layout[0];
            if (!byCol[ci])
                byCol[ci] = { idx: ci, w: 0, focused: false, solid: false };
            if (layout.tile_size)
                byCol[ci].w = Math.max(byCol[ci].w, layout.tile_size[0]);
            if (w.id === NiriService.focusedWindowId)
                byCol[ci].focused = true;
        }
        return Object.values(byCol).sort((a, b) => a.idx - b.idx);
    }

    // An empty workspace still gets a full-length dash — one undivided view.
    readonly property var segments: cols.length > 0
        ? cols : [{ idx: 1, w: 0, focused: true, solid: true }]
    readonly property real colTotal: cols.reduce((sum, c) => sum + c.w, 0)
    readonly property real colDraw:
        Math.max(6, activeW - Math.max(0, cols.length - 1) * colGap)

    implicitWidth: activeW + padX * 2
    implicitHeight: Theme.barHeight

    // Declared below the per-dash areas so clicks land on a dash, while the
    // wheel still works anywhere across the widget.
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            NiriService.dispatch([wheel.angleDelta.y > 0
                ? "focus-workspace-up" : "focus-workspace-down"]);
        }
    }

    Item {
        anchors.centerIn: parent
        width: parent.width
        height: root.avail

        Repeater {
            model: root.list

            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool active: modelData.is_active
                readonly property bool occupied: modelData.active_window_id != null

                width: parent.width
                height: root.pitch
                y: index * root.pitch

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.dispatch(["focus-workspace",
                        String(slot.modelData.idx)])
                }

                // Collapsed: length says whether it holds windows.
                Rectangle {
                    visible: !slot.active
                    x: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    width: slot.occupied ? 16 : 9
                    height: 2
                    radius: 1
                    color: slot.modelData.is_urgent ? Theme.urgent
                        : slot.occupied ? Theme.muted : Theme.faint

                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Expanded: the columns of this workspace, widths to scale.
                Row {
                    visible: slot.active
                    x: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.colGap

                    Repeater {
                        model: root.segments

                        Item {
                            id: seg
                            required property var modelData
                            readonly property real segW: modelData.solid
                                ? root.activeW
                                : (root.colTotal > 0
                                    ? Math.max(3, modelData.w / root.colTotal * root.colDraw)
                                    : 3)

                            width: segW
                            height: root.pitch
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: seg.segW
                                height: 3
                                radius: 1.5
                                color: slot.modelData.is_urgent ? Theme.urgent
                                    : seg.modelData.focused ? Theme.accent
                                    : segMouse.containsMouse ? Theme.fg : Theme.muted

                                Behavior on width {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NiriService.dispatch(["focus-column",
                                    String(seg.modelData.idx)])
                            }
                        }
                    }
                }
            }
        }
    }
}
