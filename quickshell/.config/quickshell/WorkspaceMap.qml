import QtQuick

// niri's layout in miniature, stacked the way the workspaces themselves are.
// One card per workspace, top to bottom; inside a card the columns run left to
// right at their real relative widths, and the tiles of a column stack at their
// real relative heights. Each window is its own rectangle.
//
// Proportions are exact, positions are not absolute. Niri reports tile sizes
// but not the workspace's scroll offset, so the columns are drawn filling the
// card rather than at a guessed viewport position — the same reason the widget
// this replaces drew no viewport rectangle.
Item {
    id: root

    // Connector name of the monitor this belongs to (e.g. "eDP-1")
    property string screenName: ""
    // Card height as a fraction of its width; the output's own aspect
    property real aspect: 0.625
    property real cardW: Theme.dockWidth - 12
    property real gap: 5

    readonly property real inset: 3
    readonly property real cellGap: 1.5
    readonly property real cardH: Math.round(cardW * aspect)

    // Sorted, because with a vertical stack the order carries the meaning.
    readonly property var list: NiriService.workspaces
        .filter(w => w.name !== "hidden"
            && (screenName === "" || w.output === screenName))
        .sort((a, b) => a.idx - b.idx)

    // [{ idx, w, tiles: [{ id, ti, h, focused }] }], columns left to right and
    // tiles top to bottom. Floating windows sit outside the scrolling layout
    // and have no place on the grid, so they are left out.
    function colsOf(wsId) {
        const byCol = {};
        const wins = NiriService.windows;
        for (const id in wins) {
            const w = wins[id];
            if (w.workspace_id !== wsId || w.is_floating)
                continue;
            const l = w.layout;
            if (!l || !l.pos_in_scrolling_layout || !l.tile_size)
                continue;
            const ci = l.pos_in_scrolling_layout[0];
            if (!byCol[ci])
                byCol[ci] = { idx: ci, w: 0, tiles: [] };
            // A column's width is the widest tile in it; tiles share that width.
            byCol[ci].w = Math.max(byCol[ci].w, l.tile_size[0]);
            byCol[ci].tiles.push({
                id: w.id,
                ti: l.pos_in_scrolling_layout[1],
                h: l.tile_size[1],
                focused: w.id === NiriService.focusedWindowId
            });
        }
        const cols = Object.values(byCol).sort((a, b) => a.idx - b.idx);
        for (const c of cols)
            c.tiles.sort((a, b) => a.ti - b.ti);
        return cols;
    }

    implicitWidth: Theme.dockWidth
    implicitHeight: list.length * cardH + Math.max(0, list.length - 1) * gap

    // Declared below the cards so clicks land on a card, while the wheel still
    // works anywhere across the widget.
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            NiriService.dispatch([wheel.angleDelta.y > 0
                ? "focus-workspace-up" : "focus-workspace-down"]);
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.gap

        Repeater {
            model: root.list

            Rectangle {
                id: card
                required property var modelData
                readonly property bool active: modelData.is_active
                readonly property var cols: root.colsOf(modelData.id)
                readonly property real colTotal:
                    cols.reduce((sum, c) => sum + c.w, 0)
                // Width left for the columns once the gaps between them are out
                readonly property real colDraw: Math.max(2,
                    root.cardW - root.inset * 2
                        - Math.max(0, cols.length - 1) * root.cellGap)

                width: root.cardW
                height: root.cardH
                // Past ~6 tiles in a column the minimum cell size stops
                // fitting; the excess is cut off here rather than spilling
                // out over the dock.
                clip: true
                radius: 3
                color: active ? Theme.hover : "transparent"
                border.width: 1
                border.color: modelData.is_urgent ? Theme.urgent
                    : active ? Theme.border : Theme.line

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.dispatch(["focus-workspace",
                        String(card.modelData.idx)])
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: root.inset
                    spacing: root.cellGap

                    Repeater {
                        model: card.cols

                        Column {
                            id: col
                            required property var modelData
                            readonly property real tileTotal:
                                modelData.tiles.reduce((sum, t) => sum + t.h, 0)
                            // Height left for the tiles once their gaps are out
                            readonly property real tileDraw: Math.max(2,
                                height - Math.max(0, modelData.tiles.length - 1)
                                    * root.cellGap)

                            width: card.colTotal > 0
                                ? Math.max(2, modelData.w / card.colTotal * card.colDraw)
                                : card.colDraw
                            height: parent.height
                            spacing: root.cellGap

                            Repeater {
                                model: col.modelData.tiles

                                Rectangle {
                                    id: tile
                                    required property var modelData

                                    width: col.width
                                    height: col.tileTotal > 0
                                        ? Math.max(2, modelData.h / col.tileTotal * col.tileDraw)
                                        : col.tileDraw
                                    radius: 1.5
                                    color: modelData.focused ? Theme.accent
                                        : tileMouse.containsMouse ? Theme.fg
                                        : card.active ? Theme.muted : Theme.faint

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NiriService.dispatch(
                                            ["focus-window", "--id", String(tile.modelData.id)])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
