pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color bg: "#000000"
    readonly property color fg: "#e6e6e6"
    readonly property color dim: "#b0b0b0"
    readonly property color muted: "#8a8a8a"
    readonly property color faint: "#555555"
    readonly property color accent: "#ffffff"
    readonly property color urgent: "#f2555a"

    readonly property string uiFont: "Inter"
    readonly property int fontSize: 15
    readonly property int barHeight: 34
    readonly property int dockWidth: 52
}
