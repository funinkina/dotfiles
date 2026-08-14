import QtQuick

// Right-click menu for an app, shared by the dock and the launcher.
//
// It lives inside its host window rather than taking a surface of its own —
// both hosts are (or grow) large enough to hold it, and an extra layer surface
// would fight the launcher for the keyboard. The backdrop below it catches the
// click-away, so it needs no keyboard grab to be dismissible.
Item {
    id: root

    // Empty id means closed.
    property string appId: ""
    // Connector name of the output whose workspaces the submenu lists.
    property string output: ""
    // Requested top-left in this item's coordinates; clamped to stay inside.
    property real px: 0
    property real py: 0
    property bool wsOpen: false

    readonly property bool open: appId !== ""
    readonly property var entry: open ? NiriService.entryFor(appId) : null
    readonly property var wins: open ? AppService.windowsFor(appId) : []
    readonly property bool running: wins.length > 0
    readonly property bool pinned: open && AppService.isPinned(appId)

    readonly property var workspaces: NiriService.workspaces.filter(w =>
        w.name !== "hidden" && (root.output === "" || w.output === root.output))

    visible: open
    z: 100

    function show(id, x, y) {
        wsOpen = false;
        px = x;
        py = y;
        appId = id;
    }

    function close() {
        appId = "";
        wsOpen = false;
    }

    function focusWindow() {
        const w = AppService.topWindow(appId);
        if (w)
            NiriService.dispatch(["focus-window", "--id", String(w.id)]);
        close();
    }

    function launch(workspace) {
        AppService.launchEntry(root.entry, workspace);
        close();
    }

    function togglePin() {
        if (pinned)
            AppService.unpin(appId);
        else
            AppService.pin(appId);
        close();
    }

    // Below the box, so it only sees clicks that miss it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    component MenuRow: Item {
        id: row
        property string label
        property string hint: ""
        property bool chevron: false
        property bool inset: false
        signal activated()

        width: box.width - 8
        height: 30

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 2
            color: rowMouse.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: row.inset ? 22 : 10
            anchors.right: hintText.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            id: hintText
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.chevron ? (root.wsOpen ? "⌄" : "›") : row.hint
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 13
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    Rectangle {
        id: box
        x: Math.max(6, Math.min(root.px, root.width - width - 6))
        y: Math.max(6, Math.min(root.py, root.height - height - 6))
        width: 236
        height: col.implicitHeight + 8
        radius: Theme.radius + 2
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - 8

            Text {
                width: parent.width
                leftPadding: 10
                topPadding: 6
                bottomPadding: 4
                text: root.entry?.name ?? root.appId
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            MenuRow {
                visible: root.running
                label: "Focus"
                hint: root.wins.length > 1 ? String(root.wins.length) : ""
                onActivated: root.focusWindow()
            }

            MenuRow {
                visible: !!root.entry
                label: root.running ? "New Window" : "Open"
                onActivated: root.launch()
            }

            MenuRow {
                visible: !!root.entry
                label: "Open in Workspace"
                chevron: true
                onActivated: root.wsOpen = !root.wsOpen
            }

            Repeater {
                model: root.wsOpen && !!root.entry ? root.workspaces : []

                MenuRow {
                    required property var modelData
                    inset: true
                    label: modelData.name && modelData.name !== ""
                        ? modelData.name : "Workspace " + modelData.idx
                    hint: modelData.is_active ? "•" : ""
                    onActivated: root.launch(modelData.idx)
                }
            }

            Item {
                width: parent.width
                height: 7
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Theme.line
                }
            }

            MenuRow {
                label: root.pinned ? "Unpin from Dock" : "Pin to Dock"
                onActivated: root.togglePin()
            }
        }
    }
}
