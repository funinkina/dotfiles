import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

WlSessionLock {
    id: lock
    locked: LockService.locked

    WlSessionLockSurface {
        color: Theme.bg

        readonly property string user: Quickshell.env("USER")

        // Wallpaper, dimmed
        Image {
            anchors.fill: parent
            source: "file:///home/funinkina/.config/wallpaper"
            fillMode: Image.PreserveAspectCrop
            cache: false
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.65
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        property string fullName: user
        Process {
            running: true
            command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() !== "")
                        fullName = text.trim();
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 72
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 16
            }

            Item { width: 1; height: 22 }

            ClippingRectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                height: 76
                radius: 38
                color: "#141414"

                Image {
                    anchors.fill: parent
                    source: "file:///var/lib/AccountsService/icons/" + user
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fullName
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            Item { width: 1; height: 14 }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300
                height: 42
                color: "#0d0d0d"
                border.color: pwIn.activeFocus ? Theme.fg : Theme.border
                border.width: 1

                TextInput {
                    id: pwIn
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    focus: true
                    clip: true
                    enabled: !LockService.authenticating
                    onAccepted: {
                        if (text !== "")
                            LockService.submitPassword(text);
                    }

                    Text {
                        visible: pwIn.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                    }
                }

                Connections {
                    target: LockService
                    function onInputCleared() {
                        pwIn.text = "";
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: LockService.status
                visible: text !== ""
                color: LockService.status.startsWith("Incorrect")
                    ? Theme.urgent : Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 13
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "or touch the fingerprint sensor"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
