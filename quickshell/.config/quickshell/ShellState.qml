pragma Singleton
import Quickshell
import QtQuick

// Shared state between the bar, OSD and popout panels.
Singleton {
    // Bar icon anchor positions (center-x in screen coords)
    property real volumeX: -1
    property real brightnessX: -1
    property real networkX: -1
    property real batteryX: -1
    property real mediaX: -1
    property real clockX: -1
    property real weatherX: -1
    property real screenW: 0

    signal osdRequested(string mode)
    function showOsd(mode) { osdRequested(mode); }

    // Dock visibility, toggled via `qs ipc call dock toggle` (Mod+Shift+D)
    property bool dockVisible: false

    // Custom-styled tray menu state
    property real trayMenuX: -1
    property var trayMenuHandle: null
    function openTrayMenu(handle, x) {
        trayMenuHandle = handle;
        trayMenuX = x;
        openPanel = "traymenu";
    }

    // Exclusive popout panels: "", "network", or "battery"
    property string openPanel: ""
    function togglePanel(name) { openPanel = openPanel === name ? "" : name; }
    function closePanels() { openPanel = ""; }
}
