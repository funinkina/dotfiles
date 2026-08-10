import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick

// Transient notification popups: top-right below the bar,
// sliding in from the right screen edge. History lives in the center.
PanelWindow {
    id: win

    WlrLayershell.namespace: "quickshell-notifications"

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 8; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight + 20)
    color: "transparent"

    readonly property var popups: NotifService.popups
    property bool shown: false
    visible: false

    onPopupsChanged: {
        if (popups.length > 0) {
            visible = true;
            shown = true;
        } else if (shown) {
            shown = false;
            unmapTimer.restart();
        }
    }

    Timer {
        id: unmapTimer
        interval: 240
        onTriggered: if (!win.shown) win.visible = false
    }

    Item {
        id: slide
        width: parent.width
        height: stack.implicitHeight
        x: win.shown ? 0 : width + 16
        opacity: win.shown ? 1 : 0

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Hold the stack open while it's under the pointer, so action buttons
        // stay clickable instead of timing out mid-reach.
        HoverHandler { id: stackHover }
        Binding {
            target: NotifService
            property: "paused"
            value: stackHover.hovered && win.shown
        }

        Column {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: [...win.popups].reverse().slice(0, 3)

                Rectangle {
                    id: card
                    required property var modelData
                    readonly property var n: modelData.n
                    readonly property var acts: NotifService.buttons(n)
                    width: stack.width
                    implicitHeight: body.implicitHeight + 24
                    color: cardHover.hovered ? Theme.surface : Theme.bg
                    radius: Theme.panelRadius
                    border.color: cardHover.hovered ? Theme.borderBright : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // Tracks hover across the whole card, including while the
                    // pointer sits on an action button.
                    HoverHandler { id: cardHover }

                    // Declared before the content so the action buttons, which
                    // stack above it, take the click first.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifService.activate(card.n)
                    }

                    Rectangle {
                        visible: card.n.urgency === NotificationUrgency.Critical
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 16
                        radius: 1.5
                        color: Theme.urgent
                    }

                    Column {
                        id: body
                        x: 16
                        y: 12
                        width: parent.width - 32
                        spacing: 10

                        Row {
                            id: cardRow
                            width: parent.width
                            spacing: 12

                            IconImage {
                                id: bigIcon
                                readonly property string icon: card.n.image || card.n.appIcon
                                visible: icon !== ""
                                source: icon.startsWith("/") || icon.includes("://")
                                    ? icon : Quickshell.iconPath(icon, "dialog-information")
                                implicitSize: 34
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - (bigIcon.visible ? 46 : 0)
                                spacing: 3
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    width: parent.width
                                    spacing: 5
                                    visible: appLabel.text !== ""

                                    AppGlyph {
                                        notification: card.n
                                        size: 12
                                        tint: Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        id: appLabel
                                        width: parent.width - 17
                                        text: card.n.appName
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.capitalization: Font.AllUppercase
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: card.n.summary
                                    color: Theme.fg
                                    font.family: Theme.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: card.n.body
                                    visible: text !== ""
                                    color: Theme.dim
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 6
                            visible: card.acts.length > 0

                            Repeater {
                                model: card.acts
                                NotifAction {
                                    required property var modelData
                                    action: modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
