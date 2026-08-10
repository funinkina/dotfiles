import Quickshell
import Quickshell.Wayland
import QtQuick

// Claude Code usage popout: account, plan, and rate-limit windows
// with utilization bars and reset countdowns.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-claude"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "claude" && ShellState.panelScreen === sname

    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight + 8
        left: {
            const ax = ShellState.anchorMap[sname]?.claude ?? -1;
            const sw = screen?.width ?? 1920;
            return ax < 0 ? 16
                : Math.max(8, Math.min(ax - implicitWidth / 2, sw - implicitWidth - 8));
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    readonly property var d: ClaudeService.data

    onVisibleChanged: if (visible) ClaudeService.refresh()

    component LimitRow: Column {
        id: lrow
        property string label
        property var win
        visible: win !== null && win !== undefined
        width: col.width
        spacing: 4

        readonly property real pct: win?.pct ?? 0

        Item {
            width: parent.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: lrow.label
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(lrow.pct) + "%"
                color: lrow.pct >= 90 ? Theme.urgent : Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Theme.press

            Rectangle {
                width: parent.width * Math.min(1, lrow.pct / 100)
                height: parent.height
                radius: parent.radius
                color: lrow.pct >= 90 ? Theme.urgent : Theme.accent
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        Text {
            text: "Resets " + ClaudeService.resetTime(lrow.win?.resets_at)
                + " · in " + ClaudeService.eta(lrow.win?.resets_at)
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 6
        opacity: surf.opacity

        // Header: logo + account, plan on the right
        Item {
            width: parent.width
            height: 40

            Image {
                id: logoBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                sourceSize: Qt.size(44, 44)
                source: Qt.resolvedUrl("assets/claude.svg")
                fillMode: Image.PreserveAspectFit
            }

            Column {
                anchors.left: logoBox.right
                anchors.leftMargin: 10
                anchors.right: planText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: panel.d?.account || "Claude Code"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.d?.email ?? ""
                    visible: text !== ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Text {
                id: planText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: panel.d?.plan ?? ""
                color: Theme.dim
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        Item { width: 1; height: 6 }

        LimitRow {
            label: "5-hour session"
            win: panel.d?.five_hour
        }

        Item { width: 1; height: 6 }

        LimitRow {
            label: "Weekly"
            win: panel.d?.seven_day
        }

        Item {
            visible: (panel.d?.seven_day_opus ?? null) !== null
            width: 1
            height: 6
        }

        LimitRow {
            label: "Weekly · Opus"
            win: panel.d?.seven_day_opus
        }

        Item { width: 1; height: 8 }

        Text {
            text: panel.d?.ok === false
                ? "Couldn't fetch usage — is Claude Code logged in?"
                : ClaudeService.updatedAt > 0
                    ? "Updated " + Qt.formatDateTime(new Date(ClaudeService.updatedAt), "HH:mm")
                    : "Waiting for data…"
            color: panel.d?.ok === false ? Theme.urgent : Theme.faint
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
    }
}
