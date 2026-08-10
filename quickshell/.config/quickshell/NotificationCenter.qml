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

    PanelSurface { id: surf }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.implicitHeight
        clip: true
        opacity: surf.opacity

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

                Rectangle {
                    visible: NotifService.all.length > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearLabel.implicitWidth + 16
                    height: 22
                    radius: Theme.radius - 2
                    color: clearMouse.pressed ? Theme.press
                        : clearMouse.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: clearMouse.containsMouse ? Theme.fg : Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
                    readonly property var acts: NotifService.buttons(modelData)
                    width: col.width
                    implicitHeight: body.implicitHeight + 20
                    radius: Theme.radius
                    color: Theme.surface

                    Rectangle {
                        visible: card.modelData.urgency === NotificationUrgency.Critical
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
                        x: 12
                        y: 10
                        width: parent.width - 46
                        spacing: 8

                        Row {
                            id: cardRow
                            width: parent.width
                            spacing: 10

                            IconImage {
                                id: bigIcon
                                readonly property string icon:
                                    card.modelData.image || card.modelData.appIcon
                                visible: icon !== ""
                                source: icon.startsWith("/") || icon.includes("://")
                                    ? icon : Quickshell.iconPath(icon, "dialog-information")
                                implicitSize: 30
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - (bigIcon.visible ? 40 : 0)
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    width: parent.width
                                    spacing: 5
                                    visible: appLabel.text !== ""

                                    AppGlyph {
                                        notification: card.modelData
                                        size: 12
                                        tint: Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        id: appLabel
                                        width: parent.width - 17
                                        text: card.modelData.appName
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

                    // Dismiss button
                    ColorIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        name: "window-close-symbolic"
                        size: 14
                        tint: xMouse.containsMouse ? Theme.fg : Theme.muted
                        scale: xMouse.pressed ? 0.85 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            z: -1
                            color: xMouse.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: xMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
