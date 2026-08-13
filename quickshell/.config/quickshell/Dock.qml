import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._BackgroundEffect
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: dock
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dock"

    BackgroundEffect.blurRegion: Region {
        width: dock.width
        height: dock.height
    }

    visible: ShellState.dockVisible

    anchors { left: true; top: true; bottom: true }
    implicitWidth: Theme.dockWidth
    color: "transparent"

    readonly property var pinnedIds: [
        "helium",
        "org.gnome.Nautilus",
        "chrome-cinhimbnkkaeohfgghhklpknlkffjgod-Default",
        "kitty",
        "code",
        "dev.zed.Zed",
        "chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Default",
        "slack",
        "org.gnome.Geary",
        "figma-linux-next",
        "io.github.tanaybhomia.Whisp",
        "ChatGPT",
        "org.gnome.TextEditor",
        "net.nokyan.Resources",
        "google-chrome",
        "org.gnome.Calculator"
    ]

    readonly property var wins:
        Object.values(NiriService.windows).sort((a, b) => a.id - b.id)

    readonly property var extraWins: wins.filter(w =>
        !pinnedIds.some(p => p.toLowerCase() === (w.app_id ?? "").toLowerCase()))

    function winsFor(id) {
        return wins.filter(w =>
            (w.app_id ?? "").toLowerCase() === id.toLowerCase());
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.barBg
    }

    component DockButton: Item {
        id: btn
        property string iconName
        property bool running: false
        property bool focused: false
        signal triggered()

        width: Theme.dockWidth
        height: 44

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: Theme.radius
            color: btnMouse.pressed ? Theme.press
                : btnMouse.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: btn.focused ? 22 : btnMouse.containsMouse ? 10 : btn.running ? 5 : 0
            color: btn.focused || btnMouse.containsMouse ? Theme.accent : Theme.muted
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: 34
            source: Quickshell.iconPath(btn.iconName, "application-x-executable")
            scale: btnMouse.pressed ? 0.9 : btnMouse.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    Column {
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Repeater {
            model: dock.pinnedIds

            DockButton {
                required property var modelData
                readonly property var appWins: dock.winsFor(modelData)
                readonly property var entry: NiriService.entryFor(modelData)

                iconName: entry?.icon ?? "application-x-executable"
                running: appWins.length > 0
                focused: appWins.some(w => w.id === NiriService.focusedWindowId)
                onTriggered: {
                    if (appWins.length > 0)
                        NiriService.dispatch(["focus-window", "--id", String(appWins[0].id)]);
                    else if (entry)
                        entry.execute();
                }
            }
        }

        Item {
            width: Theme.dockWidth
            height: 9
            visible: dock.extraWins.length > 0
            Rectangle {
                anchors.centerIn: parent
                width: 22
                height: 1
                color: Theme.line
            }
        }

        Repeater {
            model: dock.extraWins

            DockButton {
                required property var modelData
                iconName: NiriService.appInfo(modelData).icon
                running: true
                focused: modelData.id === NiriService.focusedWindowId
                onTriggered: NiriService.dispatch(
                    ["focus-window", "--id", String(modelData.id)])
            }
        }
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.dockWidth
        height: 36

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: Theme.radius
            color: launcherMouse.pressed ? Theme.press
                : launcherMouse.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        ColorIcon {
            anchors.centerIn: parent
            name: "view-app-grid-symbolic"
            size: 26
            tint: launcherMouse.containsMouse ? Theme.accent : Theme.muted
        }

        MouseArea {
            id: launcherMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["walker"])
        }
    }
}
