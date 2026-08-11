import QtQuick
import Quickshell

// Shared popout panel chrome: surface, outline, and a quick fade on open.
// Panel content roots bind `opacity: <id>.opacity` to fade in sync.
Rectangle {
    // Opaque by default; a window that sets a compositor blur region behind
    // itself passes the translucent bar tint instead.
    property color tint: Theme.bg

    anchors.fill: parent
    color: tint
    radius: Theme.panelRadius
    border.color: Theme.border
    border.width: 1
    opacity: (QsWindow.window?.visible ?? false) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
}
