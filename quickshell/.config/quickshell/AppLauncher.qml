import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Application launcher: drops out of the middle of the top bar as an
// extension of it — square top corners, fillets tying it into the bar, the
// same surface colour. Grid of apps above, search field at the bottom, which
// holds the keyboard from the moment it opens.
//
// Keys: type to filter, arrows move the grid selection, Enter launches,
// Escape closes (or closes the context menu first). Arrows drive the grid
// rather than the text cursor — in a grid launcher that is the useful binding.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-launcher"
    // Grabs the keyboard itself so the search field can be typed into;
    // DismissLayer skips "launcher" for that reason.
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "launcher"
        && (ShellState.panelScreen === "" || ShellState.panelScreen === sname)

    readonly property int cols: 6
    readonly property int rows: 4
    readonly property int cellW: 116
    readonly property int cellH: 104
    readonly property int pad: 12
    readonly property int searchH: 44
    readonly property int panelW: cols * cellW + pad * 2
    readonly property int panelH: pad + rows * cellH + 10 + searchH + pad

    // Anchored to the top only, so layer-shell centres it horizontally. The
    // extra width either side is room for the fillets, not for content.
    anchors { top: true }
    margins { top: Theme.barHeight }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panelW + Theme.panelRadius * 2
    implicitHeight: panelH
    color: "transparent"

    property string query: ""
    property int selected: 0
    readonly property var results: AppService.search(query)

    onQueryChanged: {
        selected = 0;
        grid.positionViewAtBeginning();
    }

    onVisibleChanged: {
        if (visible) {
            query = "";
            selected = 0;
            input.text = "";
            input.forceActiveFocus();
        } else {
            menu.close();
        }
    }

    function moveSel(d) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + d));
    }

    function activate(i) {
        const e = results[i];
        if (!e)
            return;
        ShellState.closePanels();
        AppService.launchEntry(e);
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: panel.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        CornerFillet { x: 0; y: 0 }
        CornerFillet {
            x: Theme.panelRadius + panel.panelW
            y: 0
            mirrored: true
        }

        Rectangle {
            id: surface
            x: Theme.panelRadius
            width: panel.panelW
            height: panel.panelH
            color: Theme.bg
            radius: Theme.panelRadius
            // Square where it meets the bar: the two are one shape.
            topLeftRadius: 0
            topRightRadius: 0

            GridView {
                id: grid
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: panel.pad
                anchors.leftMargin: panel.pad
                anchors.rightMargin: panel.pad
                height: panel.rows * panel.cellH
                cellWidth: panel.cellW
                cellHeight: panel.cellH
                clip: true
                model: panel.results
                boundsBehavior: Flickable.StopAtBounds

                // Selection is driven from outside (keys and hover both write
                // panel.selected), so the view only has to follow it.
                Connections {
                    target: panel
                    function onSelectedChanged() {
                        grid.positionViewAtIndex(panel.selected, GridView.Contain);
                    }
                }

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: panel.selected === index

                    width: panel.cellW
                    height: panel.cellH

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.radius + 2
                        color: tileMouse.pressed ? Theme.press
                            : tile.current ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 44
                            source: Quickshell.iconPath(tile.modelData.icon,
                                "application-x-executable")
                            scale: tileMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }

                        Text {
                            width: panel.cellW - 14
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.name ?? ""
                            color: tile.current ? Theme.fg : Theme.dim
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: if (!menu.open) panel.selected = tile.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                const p = tile.mapToItem(null, mouse.x, mouse.y);
                                menu.show(tile.modelData.id, p.x, p.y);
                            } else {
                                panel.activate(tile.index);
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: grid.horizontalCenter
                anchors.verticalCenter: grid.verticalCenter
                visible: panel.results.length === 0
                text: "No matches"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 14
            }

            Rectangle {
                id: searchBox
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: panel.pad
                height: panel.searchH
                radius: Theme.radius + 2
                color: Theme.surface
                border.color: input.activeFocus ? Theme.borderBright : Theme.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColorIcon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "system-search-symbolic"
                    size: 16
                    tint: Theme.muted
                }

                Text {
                    id: countLabel
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: panel.query !== ""
                    text: panel.results.length + (panel.results.length === 1
                        ? " result" : " results")
                    color: Theme.faint
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: countLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    clip: true
                    focus: true
                    onTextChanged: panel.query = text

                    Text {
                        visible: input.text === ""
                        text: "Search applications"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }

                    Keys.onPressed: e => {
                        if (menu.open) {
                            if (e.key === Qt.Key_Escape) {
                                menu.close();
                                e.accepted = true;
                            }
                            return;
                        }
                        switch (e.key) {
                        case Qt.Key_Escape:
                            ShellState.closePanels();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            panel.activate(panel.selected);
                            break;
                        case Qt.Key_Right:
                            panel.moveSel(1);
                            break;
                        case Qt.Key_Left:
                            panel.moveSel(-1);
                            break;
                        case Qt.Key_Down:
                            panel.moveSel(panel.cols);
                            break;
                        case Qt.Key_Up:
                            panel.moveSel(-panel.cols);
                            break;
                        case Qt.Key_Home:
                            panel.selected = 0;
                            break;
                        case Qt.Key_End:
                            panel.selected = Math.max(0, panel.results.length - 1);
                            break;
                        default:
                            return;
                        }
                        e.accepted = true;
                    }
                }
            }
        }

        AppMenu {
            id: menu
            anchors.fill: parent
            output: panel.sname
        }
    }
}
