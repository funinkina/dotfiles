pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // Surfaces, darkest to lightest
    readonly property color bg: "#121212"       // bar, dock, panels
    readonly property color surface: "#1d1d1d"  // cards, inputs, idle tiles
    readonly property color hover: "#282828"
    readonly property color press: "#343434"

    // Text
    readonly property color fg: "#f2f2f2"
    readonly property color dim: "#c6c6c6"
    readonly property color muted: "#9b9b9b"
    readonly property color faint: "#6b6b6b"    // placeholders, disabled

    // Lines and outlines
    readonly property color line: "#2b2b2b"         // dividers, bar hairline
    readonly property color border: "#454545"       // panel and control outlines
    readonly property color borderBright: "#bcbcbc" // focused inputs

    readonly property color accent: "#ffffff"
    readonly property color accentFg: "#000000"  // text on accent fills
    readonly property color urgent: "#f2555a"

    readonly property string uiFont: "SF Pro Text"
    readonly property int fontSize: 15
    readonly property int barHeight: 34
    readonly property int dockWidth: 52
    readonly property int radius: 6
}
