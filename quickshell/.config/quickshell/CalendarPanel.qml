import Quickshell
import Quickshell.Wayland
import QtQuick

// Clock popout: detailed time/date + month calendar with navigation.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-calendar"

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "clock" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.clock ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 302
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property var loc: Qt.locale()
    // Qt: Monday=1..Sunday=7; JS Date.getDay(): Sunday=0
    readonly property int firstDow: loc.firstDayOfWeek % 7

    property int viewYear: 2026
    property int viewMonth: 0
    property var grid: []

    onVisibleChanged: {
        if (visible) {
            const now = new Date();
            viewYear = now.getFullYear();
            viewMonth = now.getMonth();
            rebuild();
        }
    }

    function rebuild() {
        const today = new Date();
        const first = new Date(viewYear, viewMonth, 1);
        const lead = (first.getDay() - firstDow + 7) % 7;
        const start = new Date(viewYear, viewMonth, 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                today: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate()
            });
        }
        grid = out;
    }

    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
        rebuild();
    }

    function weekNumber(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dayNum = (t.getUTCDay() + 6) % 7;
        t.setUTCDate(t.getUTCDate() - dayNum + 3);
        const firstThursday = new Date(Date.UTC(t.getUTCFullYear(), 0, 4));
        const ftDayNum = (firstThursday.getUTCDay() + 6) % 7;
        firstThursday.setUTCDate(firstThursday.getUTCDate() - ftDayNum + 3);
        return 1 + Math.round((t - firstThursday) / 604800000);
    }

    function dayOfYear(d) {
        return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000);
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 4
        opacity: surf.opacity

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }

        Text {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            color: Theme.dim
            font.family: Theme.uiFont
            font.pixelSize: 13
        }

        Text {
            text: `Week ${panel.weekNumber(clock.date)} · Day ${panel.dayOfYear(clock.date)} of the year`
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 12
        }

        Item { width: 1; height: 10 }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        Item { width: 1; height: 10 }

        // Month header with navigation
        Item {
            width: parent.width
            height: 22

            ColorIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "go-previous-symbolic"
                size: 14
                tint: prevMouse.containsMouse ? Theme.fg : Theme.muted
                scale: prevMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.shiftMonth(-1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: panel.loc.monthName(panel.viewMonth, Locale.LongFormat)
                    + " " + panel.viewYear
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            ColorIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "go-next-symbolic"
                size: 14
                tint: nextMouse.containsMouse ? Theme.fg : Theme.muted
                scale: nextMouse.pressed ? 0.85 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.shiftMonth(1)
                }
            }
        }

        Item { width: 1; height: 6 }

        // Weekday header
        Row {
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: (col.width) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.loc.dayName(
                        ((panel.loc.firstDayOfWeek - 1 + index) % 7) + 1,
                        Locale.ShortFormat).slice(0, 2)
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        Item { width: 1; height: 2 }

        // Day grid
        Grid {
            columns: 7

            Repeater {
                model: panel.grid

                Item {
                    required property var modelData
                    width: col.width / 7
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 5
                        color: parent.modelData.today ? Theme.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.modelData.day
                            color: parent.parent.modelData.today ? Theme.accentFg
                                : parent.parent.modelData.inMonth ? Theme.fg : Theme.faint
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: parent.parent.modelData.today
                                ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
