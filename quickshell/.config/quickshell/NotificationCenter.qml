import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick

// Notification center: list of undismissed notifications with dismissal.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-notifcenter"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "notifs" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins { top: Theme.barHeight; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380
    implicitHeight: Math.min(560, flick.contentHeight + 28)
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.implicitHeight
        clip: true

        Column {
            id: col
            width: flick.width
            spacing: 8

            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                }

                Text {
                    visible: NotifService.all.length > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear all"
                    color: clearMouse.containsMouse ? Theme.fg : Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: NotifService.dismissAll()
                    }
                }
            }

            Text {
                visible: NotifService.all.length === 0
                text: "No notifications"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 13
            }

            Repeater {
                model: [...NotifService.all].reverse()

                Rectangle {
                    id: card
                    required property var modelData
                    width: col.width
                    implicitHeight: cardRow.implicitHeight + 20
                    color: "#141414"

                    Rectangle {
                        visible: card.modelData.urgency === NotificationUrgency.Critical
                        anchors.left: parent.left
                        width: 3
                        height: parent.height
                        color: Theme.urgent
                    }

                    Row {
                        id: cardRow
                        x: 12
                        y: 10
                        width: parent.width - 46
                        spacing: 10

                        IconImage {
                            readonly property string icon:
                                card.modelData.image || card.modelData.appIcon
                            visible: icon !== ""
                            source: icon.startsWith("/") || icon.includes("://")
                                ? icon : Quickshell.iconPath(icon, "dialog-information")
                            implicitSize: 30
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - (parent.children[0].visible ? 40 : 0)
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: card.modelData.appName
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
                                text: card.modelData.summary
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
                                text: card.modelData.body
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

                    // Dismiss button
                    ColorIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "window-close-symbolic"
                        size: 14
                        tint: xMouse.containsMouse ? Theme.fg : Theme.muted

                        MouseArea {
                            id: xMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            onClicked: card.modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
