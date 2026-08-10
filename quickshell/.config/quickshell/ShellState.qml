pragma Singleton
import Quickshell
import QtQuick

// Shared state between the bar, OSD and popout panels.
Singleton {
    id: root

    // Per-screen anchor positions: screenName -> { key: centerX }
    // Keys: volume, brightness, network, battery, media, clock, weather, traymenu
    property var anchorMap: ({})
    function setAnchor(screen, key, x) {
        const m = Object.assign({}, anchorMap);
        m[screen] = Object.assign({}, m[screen] ?? {});
        m[screen][key] = x;
        anchorMap = m;
    }

    signal osdRequested(string mode)
    function showOsd(mode) { osdRequested(mode); }

    // Dock visibility, toggled via `qs ipc call dock toggle` (Mod+Shift+D)
    property bool dockVisible: false

    // Custom-styled tray menu state
    property var trayMenuHandle: null
    function openTrayMenu(handle, x, screen) {
        trayMenuHandle = handle;
        setAnchor(screen, "traymenu", x);
        panelScreen = screen;
        openPanel = "traymenu";
    }

    // Exclusive popout panels; panelScreen is the screen they open on
    // ("" = every screen, used by the centered power menu via IPC)
    property string openPanel: ""
    property string panelScreen: ""
    function togglePanel(name, screen) {
        screen = screen ?? "";
        if (openPanel === name && panelScreen === screen) {
            openPanel = "";
        } else {
            panelScreen = screen;
            openPanel = name;
        }
    }
    function closePanels() { openPanel = ""; }
}
