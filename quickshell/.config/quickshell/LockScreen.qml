import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// WlSessionLock's default property is `surface`, a single Component — helper
// objects cannot be nested inside it or they get swallowed by that slot, so
// the timing logic lives out here in a Scope alongside it.
Scope {
    id: root

    // `locked` is driven imperatively rather than bound to LockService.
    // Locking has to take effect on the spot, but unlocking must outlast the
    // fade: the compositor destroys the lock surface the instant this goes
    // false, so a plain binding would leave nothing on screen to animate.
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
                lock.locked = true;     // never delayed
            } else if (lock.locked) {
                root.unlocking = true;  // fade out, then drop the surface
                closeTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.fadeOut + 40   // outlast the fade so it never cuts early
        // `unlocking` is deliberately left set: clearing it here would make the
        // content opaque again for however many frames the surface takes to go
        // away. The next lock resets it before the surface is recreated.
        onTriggered: lock.locked = false
    }

    WlSessionLock {
        id: lock

        WlSessionLockSurface {
            id: surface
            color: Theme.bg

            readonly property string user: Quickshell.env("USER")
            property string fullName: user

            // Starts false so the fade has somewhere to animate from, and is
            // set from a rendered frame rather than Component.onCompleted: the
            // surface takes 600ms+ to come up, and a Behavior begun while the
            // render loop is still stalled jumps straight to its end value once
            // frames resume. Waiting a few frames makes the fade-in land more
            // often, though not on every lock; the fade-out is unaffected,
            // since by then the surface is warm.
            property bool revealed: false

            FrameAnimation {
                property int frames: 0
                running: true
                onTriggered: {
                    // A few frames, not one: the surface keeps stalling just
                    // after its first, and a fade begun inside that stall
                    // jumps straight to its end value.
                    if (++frames < 5)
                        return;
                    surface.revealed = true;
                    running = false;
                }
            }

            readonly property bool shown: revealed && !root.unlocking

            // Content fades over the surface's own opaque colour, so the desktop
            // is never briefly visible through it while locking.
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

                // Wallpaper, dimmed
                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: "file:///home/funinkina/.config/wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    // Decoded off the GUI thread; a synchronous decode of the
                    // 2880x1800 file stalled the first frames of the fade by
                    // nearly a second.
                    asynchronous: true
                    // Decode straight to screen size; the file is 2982x2108
                    // and the extra pixels only cost upload time.
                    sourceSize.width: surface.width * Screen.devicePixelRatio
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.65
                }

                Column {
                    id: clockCol
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.33 - height / 2
                    spacing: 6
                    // Settles down from above as the login block rises to meet it.
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
                    transform: Translate { y: surface.lift }

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
    }
}
