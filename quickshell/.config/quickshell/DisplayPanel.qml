import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Display popout, per monitor:
//  - internal panel (eDP-*): backlight brightness slider
//  - external monitors: DDC/CI brightness + contrast via ddcutil
//  - refresh rate switcher (wrapping grid; externals expose many rates)
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-display"

    readonly property string sname: screen?.name ?? ""
    readonly property bool isInternal: sname.startsWith("eDP")

    visible: ShellState.openPanel === "display" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.brightness ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    // ---- Refresh rates (niri) ----
    property var rates: []

    onVisibleChanged: {
        if (visible) {
            outProc.running = true;
            if (!isInternal) {
                if (ddcNum < 0)
                    ddcDetect.running = true;
                else
                    ddcGet.running = true;
            }
        }
    }

    Process {
        id: outProc
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let outs;
                try { outs = JSON.parse(text); } catch (e) { return; }
                const o = outs[panel.sname];
                if (!o)
                    return;
                const cm = o.modes[o.current_mode];
                panel.rates = o.modes
                    .filter(m => m.width === cm.width && m.height === cm.height)
                    .sort((a, b) => a.refresh_rate - b.refresh_rate)
                    .map(m => ({
                        label: Math.round(m.refresh_rate / 1000) + " Hz",
                        mode: `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`,
                        active: m.refresh_rate === cm.refresh_rate
                    }));
            }
        }
    }

    Timer {
        id: refetchTimer
        interval: 600
        onTriggered: outProc.running = true
    }

    function setMode(mode) {
        Quickshell.execDetached(["niri", "msg", "output", panel.sname, "mode", mode]);
        refetchTimer.restart();
    }

    // ---- Internal backlight ----
    readonly property int bCur: parseInt(bFile.text()) || 0
    readonly property int bMax: parseInt(bMaxFile.text()) || 1
    readonly property real bVal: bCur / bMax

    FileView {
        id: bFile
        path: "/sys/class/backlight/intel_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: bMaxFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    function setBacklight(v) {
        v = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "set", Math.round(v * 100) + "%"]);
    }

    // ---- External DDC/CI (ddcutil) ----
    property int ddcNum: -1
    property bool ddcReady: false
    property real ddcBri: 0    // 0..1
    property real ddcCon: 0

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = -1;
                for (const line of text.split("\n")) {
                    const dm = line.match(/^Display (\d+)/);
                    if (dm)
                        cur = parseInt(dm[1]);
                    else if (line.includes("DRM connector") && line.includes(panel.sname) && cur > 0) {
                        panel.ddcNum = cur;
                        ddcGet.running = true;
                        return;
                    } else if (line.startsWith("Invalid display")) {
                        cur = -1;
                    }
                }
            }
        }
    }

    Process {
        id: ddcGet
        command: ["ddcutil", "-d", String(panel.ddcNum), "getvcp", "10", "12", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const m = line.match(/^VCP (\d+) C (\d+) (\d+)/);
                    if (!m)
                        continue;
                    const v = parseInt(m[2]) / parseInt(m[3]);
                    if (m[1] === "10")
                        panel.ddcBri = v;
                    else if (m[1] === "12")
                        panel.ddcCon = v;
                    panel.ddcReady = true;
                }
            }
        }
    }

    // Debounced writers: DDC is slow, apply only the latest value
    Timer {
        id: briWrite
        interval: 250
        onTriggered: Quickshell.execDetached(["ddcutil", "-d", String(panel.ddcNum),
            "setvcp", "10", String(Math.round(panel.ddcBri * 100))])
    }

    Timer {
        id: conWrite
        interval: 250
        onTriggered: Quickshell.execDetached(["ddcutil", "-d", String(panel.ddcNum),
            "setvcp", "12", String(Math.round(panel.ddcCon * 100))])
    }

    function setDdcBri(v) {
        ddcBri = Math.max(0, Math.min(1, v));
        briWrite.restart();
    }

    function setDdcCon(v) {
        ddcCon = Math.max(0, Math.min(1, v));
        conWrite.restart();
    }

    // ---- UI ----
    component SliderRow: Item {
        id: srow
        property real value: 0
        property string iconName: "display-brightness-symbolic"
        signal moved(real v)

        width: col.width
        height: 22

        ColorIcon {
            id: sIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            size: 16
            name: srow.iconName
        }

        Text {
            id: sPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round(srow.value * 100) + "%"
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Item {
            anchors.left: sIcon.right
            anchors.right: sPct.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: parent.height

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: sMouse.containsMouse || sMouse.pressed ? 7 : 5
                radius: height / 2
                color: Theme.press
                Behavior on height { NumberAnimation { duration: 100 } }

                Rectangle {
                    width: parent.width * Math.min(1, srow.value)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            // Drag knob, shown while hovering or dragging
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * Math.min(1, srow.value) - width / 2))
                width: 13
                height: 13
                radius: 6.5
                color: Theme.accent
                border.color: Theme.bg
                border.width: 2
                opacity: sMouse.containsMouse || sMouse.pressed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: sMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => srow.moved(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        srow.moved(mouse.x / width);
                }
                onWheel: wheel => srow.moved(
                    srow.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
    }

    component SectionLabel: Text {
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6
        opacity: surf.opacity

        SectionLabel { text: panel.isInternal ? "Brightness" : "Brightness · DDC" }

        Item { width: 1; height: 2 }

        // Internal: backlight
        SliderRow {
            visible: panel.isInternal
            value: panel.bVal
            onMoved: v => panel.setBacklight(v)
        }

        // External: DDC brightness
        SliderRow {
            visible: !panel.isInternal && panel.ddcReady
            value: panel.ddcBri
            onMoved: v => panel.setDdcBri(v)
        }

        Text {
            visible: !panel.isInternal && !panel.ddcReady
            text: panel.ddcNum < 0 ? "Detecting monitor…" : "Reading values…"
            color: Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Item { visible: !panel.isInternal; width: 1; height: 8 }

        SectionLabel { visible: !panel.isInternal; text: "Contrast" }

        Item { visible: !panel.isInternal; width: 1; height: 2 }

        SliderRow {
            visible: !panel.isInternal && panel.ddcReady
            value: panel.ddcCon
            iconName: "weather-clear-symbolic"
            onMoved: v => panel.setDdcCon(v)
        }

        Item { width: 1; height: 10 }

        SectionLabel { text: "Refresh rate" }

        Item { width: 1; height: 4 }

        // Wrapping grid: 3 per row, individually bordered cells
        Grid {
            columns: 3
            columnSpacing: 4
            rowSpacing: 4
            visible: panel.rates.length > 0

            Repeater {
                model: panel.rates

                Rectangle {
                    required property var modelData
                    width: (col.width - 8) / 3
                    height: 28
                    radius: Theme.radius
                    color: modelData.active ? Theme.accent
                        : rateMouse.pressed ? Theme.press
                        : rateMouse.containsMouse ? Theme.hover : "transparent"
                    border.color: modelData.active ? Theme.accent : Theme.border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.modelData.active ? Theme.accentFg : Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: rateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.setMode(parent.modelData.mode)
                    }
                }
            }
        }
    }
}
