import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick

// Transient notification popups: top-center below the bar,
// sliding down from its edge. History lives in the notification center.
PanelWindow {
    id: win

    WlrLayershell.namespace: "quickshell-notifications"

    anchors { top: true }
    margins { top: Theme.barHeight }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420
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
        y: win.shown ? 0 : -height - Theme.barHeight
        opacity: win.shown ? 1 : 0

        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        TopSeparator { z: 1 }

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
                    width: stack.width
                    implicitHeight: cardRow.implicitHeight + 24
                    color: Theme.bg

                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        visible: card.n.urgency === NotificationUrgency.Critical
                        anchors.left: parent.left
                        width: 3
                        height: parent.height
                        color: Theme.urgent
                    }

                    Row {
                        id: cardRow
                        x: 16
                        y: 12
                        width: parent.width - 32
                        spacing: 12

                        IconImage {
                            readonly property string icon: card.n.image || card.n.appIcon
                            visible: icon !== ""
                            source: icon.startsWith("/") || icon.includes("://")
                                ? icon : Quickshell.iconPath(icon, "dialog-information")
                            implicitSize: 34
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - (parent.children[0].visible ? 46 : 0)
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: card.n.appName
                                visible: text !== ""
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.capitalization: Font.AllUppercase
                                elide: Text.ElideRight
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

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.n.dismiss()
                    }
                }
            }
        }
    }
}
