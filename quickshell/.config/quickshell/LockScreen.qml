import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

WlSessionLock {
    id: lock
    locked: LockService.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.bg

        readonly property string user: Quickshell.env("USER")

        // Wallpaper, dimmed
        Image {
            id: wallpaper
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
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.33 - height / 2
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 108
                font.weight: Font.Bold
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 20
                }

                Text {
                    visible: WeatherService.data !== null
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 20
                }

                ColorIcon {
                    visible: WeatherService.data !== null
                    anchors.verticalCenter: parent.verticalCenter
                    name: WeatherService.iconFor()
                    size: 20
                }

                Text {
                    visible: WeatherService.data !== null
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(WeatherService.temp) + "°"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 20
                }
            }
        }

        // Anchored under the clock rather than inside it, so the clock keeps
        // its position whether or not something is playing.
        LockMedia {
            anchors.horizontalCenter: clockCol.horizontalCenter
            anchors.top: clockCol.bottom
            anchors.topMargin: 28
        }

        LockNotifications {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
        }

        Image {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            source: "file:///usr/share/pixmaps/archlinux-logo-text-dark.svg"
            sourceSize.height: 80
            fillMode: Image.PreserveAspectFit
            opacity: 0.85
        }

        Column {
            id: loginCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            spacing: 10

            ClippingRectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                height: 76
                radius: 38
                color: Theme.surface

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

            BlurPanel {
                id: field
                blurSource: wallpaper
                blurRoot: surface

                anchors.horizontalCenter: parent.horizontalCenter
                width: 300
                height: 34
                radius: Theme.radius
                border.color: pwIn.activeFocus ? Theme.borderBright : Theme.border
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 100 } }

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
