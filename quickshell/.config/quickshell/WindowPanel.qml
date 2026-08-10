import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Focused-window actions popout (opens from the app name in the bar):
// fullscreen / float / close, move to another workspace or monitor.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-window"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "window" && ShellState.panelScreen === sname

    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight + 8
        left: {
            const ax = ShellState.anchorMap[sname]?.window ?? -1;
            const sw = screen?.width ?? 1920;
            return ax < 0 ? (sw - implicitWidth) / 2
                : Math.max(8, Math.min(ax - implicitWidth / 2, sw - implicitWidth - 8));
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    readonly property var win: NiriService.focusedWindow
    readonly property var info: NiriService.appInfo(win)
    readonly property var ws: NiriService.workspaces.find(w => w.id === win?.workspace_id) ?? null
    // Workspaces on the window's monitor, in dock order
    readonly property var wsOptions: NiriService.workspaces.filter(w =>
        w.name !== "hidden" && (ws === null || w.output === ws.output))
    readonly property var otherOutputs: Quickshell.screens
        .map(s => s.name).filter(o => o !== (ws?.output ?? sname))

    // Nothing to act on once focus vanishes (window closed some other way)
    onWinChanged: if (visible && win === null) ShellState.closePanels()

    function act(args) {
        NiriService.dispatch(args);
        ShellState.closePanels();
    }

    component SectionLabel: Text {
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component ActionRow: Rectangle {
        id: arow
        property string icon
        property string label
        signal triggered()

        width: col.width
        height: 32
        radius: Theme.radius
        color: arMouse.pressed ? Theme.press
            : arMouse.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        ColorIcon {
            id: arIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            name: arow.icon
            size: 15
            tint: arMouse.containsMouse ? Theme.fg : Theme.dim
        }

        Text {
            anchors.left: arIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: arow.label
            color: arMouse.containsMouse ? Theme.fg : Theme.dim
            font.family: Theme.uiFont
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        MouseArea {
            id: arMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arow.triggered()
        }
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 4
        opacity: surf.opacity

        // App header: real icon + name + window title
        Row {
            width: parent.width
            spacing: 10

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 30
                source: panel.info.icon
                    ? Quickshell.iconPath(panel.info.icon, "application-x-executable") : ""
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                spacing: 1

                Text {
                    width: parent.width
                    text: panel.info.name
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.win?.title ?? ""
                    visible: text !== "" && text !== panel.info.name
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        Item { width: 1; height: 8 }
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Item { width: 1; height: 8 }

        ActionRow {
            icon: "view-fullscreen-symbolic"
            label: "Toggle fullscreen"
            onTriggered: if (panel.win)
                panel.act(["fullscreen-window", "--id", String(panel.win.id)])
        }

        ActionRow {
            icon: "view-restore-symbolic"
            label: panel.win?.is_floating ? "Tile window" : "Float window"
            onTriggered: if (panel.win)
                panel.act(["toggle-window-floating", "--id", String(panel.win.id)])
        }

        ActionRow {
            icon: "window-close-symbolic"
            label: "Close window"
            onTriggered: if (panel.win)
                panel.act(["close-window", "--id", String(panel.win.id)])
        }

        Item { width: 1; height: 8 }

        SectionLabel { text: "Move to workspace" }

        Item { width: 1; height: 4 }

        // Segmented workspace picker; the window's current one is marked
        ClippingRectangle {
            width: parent.width
            height: 28
            radius: Theme.radius
            contentInsideBorder: true
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            Row {
                anchors.fill: parent

                Repeater {
                    model: panel.wsOptions

                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool current:
                            modelData.id === panel.win?.workspace_id
                        width: parent.width / Math.max(1, panel.wsOptions.length)
                        height: parent.height
                        color: current ? Theme.accent
                            : wsMouse.pressed ? Theme.press
                            : wsMouse.containsMouse ? Theme.hover : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            visible: parent.index > 0
                            anchors.left: parent.left
                            width: 1
                            height: parent.height
                            color: Theme.line
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.idx
                            color: parent.current ? Theme.accentFg : Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.current
                                ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!parent.current && panel.win)
                                    panel.act(["move-window-to-workspace",
                                        "--window-id", String(panel.win.id),
                                        String(parent.modelData.idx)]);
                            }
                        }
                    }
                }
            }
        }

        Item { visible: panel.otherOutputs.length > 0; width: 1; height: 8 }

        SectionLabel {
            visible: panel.otherOutputs.length > 0
            text: "Move to display"
        }

        Item { visible: panel.otherOutputs.length > 0; width: 1; height: 4 }

        Repeater {
            model: panel.otherOutputs

            ActionRow {
                required property var modelData
                icon: "video-display-symbolic"
                label: modelData
                onTriggered: if (panel.win)
                    panel.act(["move-window-to-monitor",
                        "--id", String(panel.win.id), modelData])
            }
        }
    }
}
