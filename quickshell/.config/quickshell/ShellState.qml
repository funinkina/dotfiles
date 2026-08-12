pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property var anchorMap: ({})
    function setAnchor(screen, key, x) {
        const m = Object.assign({}, anchorMap);
        m[screen] = Object.assign({}, m[screen] ?? {});
        m[screen][key] = x;
        anchorMap = m;
    }

    signal osdRequested(string mode)
    function showOsd(mode) { osdRequested(mode); }

    // A volume/brightness key was pressed. Relayed rather than acted on here:
    // each Osd instance holds its own live values and decides whether the
    // press actually moved anything.
    signal osdStepped(string mode, string dir)
    function stepOsd(mode, dir) { osdStepped(mode, dir); }

    property bool dockVisible: false

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
    function isOpen(name, screen) {
        return openPanel === name && panelScreen === screen;
    }
}
