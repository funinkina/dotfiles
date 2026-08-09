import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: dock
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-dock"

    anchors { left: true; top: true; bottom: true }
    implicitWidth: Theme.dockWidth
    color: "transparent"

    // Mirrors gsettings org.gnome.shell favorite-apps
    readonly property var pinnedIds: [
        "helium",
        "org.gnome.Nautilus",
        "chrome-cinhimbnkkaeohfgghhklpknlkffjgod-Default",
        "com.mitchellh.ghostty",
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
        color: Theme.bg
    }

    component DockButton: Item {
        id: btn
        property string iconName
        property bool running: false
        property bool focused: false
        signal triggered()

        width: Theme.dockWidth
        height: 40

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
            implicitSize: 28
            source: Quickshell.iconPath(btn.iconName, "application-x-executable")
            opacity: btn.focused || btnMouse.containsMouse ? 1.0
                : btn.running ? 0.85 : 0.55
            scale: btnMouse.containsMouse ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
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

        // Separator before running apps that aren't pinned
        Item {
            width: Theme.dockWidth
            height: 9
            visible: dock.extraWins.length > 0
            Rectangle {
                anchors.centerIn: parent
                width: 22
                height: 1
                color: Theme.faint
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

    // Launcher at the bottom
    Item {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.dockWidth
        height: 36

        ColorIcon {
            anchors.centerIn: parent
            name: "view-app-grid-symbolic"
            size: 22
            tint: launcherMouse.containsMouse ? Theme.accent : Theme.muted
        }

        MouseArea {
            id: launcherMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Quickshell.execDetached(["vicinae", "toggle"])
        }
    }
}
