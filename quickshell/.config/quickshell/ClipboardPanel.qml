import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "clipboard"
        && (ShellState.panelScreen === "" || ShellState.panelScreen === sname)

    readonly property int pad: 12
    readonly property int searchH: 44
    readonly property int panelW: 620
    readonly property int maxListH: 396

    readonly property int listH: Math.round(
        Math.max(96, Math.min(maxListH, list.contentHeight)))
    readonly property int panelH: pad + listH + 10 + searchH + pad

    anchors { top: true }
    margins { top: Theme.barHeight }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panelW + Theme.panelRadius * 2
    implicitHeight: panelH
    color: "transparent"

    property string query: ""
    property int selected: 0

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const all = ClipboardService.entries;
        if (q === "")
            return all;
        return all.filter(e => e.image
            ? ("image " + e.meta).toLowerCase().includes(q)
            : e.text.toLowerCase().includes(q));
    }

    onQueryChanged: {
        selected = 0;
        list.positionViewAtBeginning();
    }

    onVisibleChanged: {
        if (!visible)
            return;
        query = "";
        input.text = "";
        selected = 0;
        ClipboardService.refresh();
        input.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    onResultsChanged: if (selected >= results.length)
        selected = Math.max(0, results.length - 1)

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
        ClipboardService.paste(e);
    }

    function removeAt(i) {
        const e = results[i];
        if (!e)
            return;
        ClipboardService.remove(e);
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
            topLeftRadius: 0
            topRightRadius: 0

            ListView {
                id: list
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: panel.pad
                anchors.leftMargin: panel.pad
                anchors.rightMargin: panel.pad
                height: panel.listH
                clip: true
                model: panel.results
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                Connections {
                    target: panel
                    function onSelectedChanged() {
                        list.positionViewAtIndex(panel.selected, ListView.Contain);
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: panel.selected === index

                    width: list.width
                    height: modelData.image ? 72 : 52

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius + 2
                        color: rowMouse.pressed ? Theme.press
                            : row.current ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Text {
                        id: ordinal
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        text: String(row.index + 1)
                        color: row.current ? Theme.muted : Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                    }

                    Image {
                        id: thumb
                        anchors.left: ordinal.right
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.image
                        width: 56
                        height: 56
                        source: row.modelData.thumb
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 112
                        sourceSize.height: 112
                        asynchronous: true
                    }

                    Text {
                        anchors.left: row.modelData.image ? thumb.right : ordinal.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.image
                            ? row.modelData.meta : row.modelData.text
                        color: row.modelData.image
                            ? Theme.muted
                            : row.current ? Theme.fg : Theme.dim
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: panel.selected = row.index
                        onClicked: panel.activate(row.index)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: list.horizontalCenter
                anchors.verticalCenter: list.verticalCenter
                visible: panel.results.length === 0
                text: ClipboardService.entries.length === 0
                    ? "Clipboard history is empty" : "No matches"
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
                    id: hint
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: panel.results.length > 0
                    text: "↵ paste · ⌦ delete"
                    color: Theme.faint
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: hint.left
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
                        text: "Filter clipboard history"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }

                    Keys.onPressed: e => {
                        switch (e.key) {
                        case Qt.Key_Escape:
                            ShellState.closePanels();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            panel.activate(panel.selected);
                            break;
                        case Qt.Key_Down:
                            panel.moveSel(1);
                            break;
                        case Qt.Key_Up:
                            panel.moveSel(-1);
                            break;
                        case Qt.Key_PageDown:
                            panel.moveSel(5);
                            break;
                        case Qt.Key_PageUp:
                            panel.moveSel(-5);
                            break;
                        case Qt.Key_Delete:
                            panel.removeAt(panel.selected);
                            break;
                        default:
                            return;
                        }
                        e.accepted = true;
                    }
                }
            }
        }
    }
}
