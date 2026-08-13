import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

Scope {
    id: root

    property bool unlocking: false
    readonly property int fadeIn: 320
    readonly property int fadeOut: 200

    Component.onCompleted: lock.locked = LockService.locked

    Connections {
        target: LockService
        function onLockedChanged() {
            if (LockService.locked) {
                closeTimer.stop();
                root.unlocking = false;
                lock.locked = true;   
            } else if (lock.locked) {
                root.unlocking = true;
                closeTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.fadeOut + 40
        onTriggered: lock.locked = false
    }

    WlSessionLock {
        id: lock

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            readonly property string user: Quickshell.env("USER")
            property string fullName: user
            property bool revealed: false

            FrameAnimation {
                property int frames: 0
                running: true
                onTriggered: {
                    if (++frames < 5)
                        return;
                    surface.revealed = true;
                    running = false;
                }
            }

            readonly property bool shown: revealed && !root.unlocking

            property real lift: shown ? 0 : 14
            Behavior on lift {
                NumberAnimation {
                    duration: root.unlocking ? root.fadeOut : root.fadeIn
                    easing.type: Easing.OutCubic
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

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

            Item {
                id: content
                anchors.fill: parent
                opacity: surface.shown ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.unlocking ? root.fadeOut : root.fadeIn
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: "file:///home/funinkina/.config/wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: true
                    sourceSize.width: surface.width * Screen.devicePixelRatio
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.65
                }

                MouseArea {
                    anchors.fill: parent
                    z: 10
                    hoverEnabled: true
                    acceptedButtons: LockService.awake ? Qt.NoButton : Qt.AllButtons
                    onPositionChanged: if (LockService.awake) LockService.wake()
                    onPressed: LockService.wake()
                }

                Column {
                    id: clockCol
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.33 - height / 2
                    spacing: 6
                    transform: Translate { y: -surface.lift * 0.6 }

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
                    transform: Translate { y: surface.lift }

                    opacity: LockService.awake ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

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
                        blurRoot: content

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 300
                        height: 34
                        radius: height / 2
                        border.width: 0
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 0.5
                            radius: height / 2
                            color: "transparent"
                            antialiasing: true
                            border.width: 1 / Screen.devicePixelRatio
                            border.color: "#30ffffff"
                        }

                        TextInput {
                            id: pwIn
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 14
                            focus: true
                            clip: true
                            enabled: !LockService.authenticating
                            Keys.onPressed: event => {
                                if (!LockService.awake)
                                    event.accepted = true;
                                LockService.wake();
                            }
                            onAccepted: {
                                if (text !== "")
                                    LockService.submitPassword(text);
                            }

                            Text {
                                visible: pwIn.text === ""
                                anchors.centerIn: parent
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
                        visible: !LockService.fpBroken
                        text: "or touch the fingerprint sensor"
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 96
                    spacing: 8
                    transform: Translate { y: surface.lift }

                    opacity: LockService.awake ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    ColorIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "changes-prevent-symbolic"
                        tint: Theme.dim
                        size: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Click or press a key to unlock"
                        color: Theme.dim
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
