import Quickshell
import Quickshell.Wayland
import QtQuick

// Clock popout: detailed time/date + month calendar, with the weather
// details alongside. Opened by the combined date/weather bar item.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-calendar"
    // Grabs the keyboard itself so the city field can be typed into;
    // DismissLayer skips "clock" for that reason.
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "clock" && ShellState.panelScreen === sname

    property bool editing: false

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
    implicitWidth: 603
    implicitHeight: Math.max(calCol.implicitHeight, wxCol.implicitHeight) + 28
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

    // Day whose holidays are listed below the grid; defaults to today
    property string selKey: HolidayService.key(new Date())
    readonly property var selEvents: HolidayService.forKey(selKey)

    readonly property var d: WeatherService.data

    onVisibleChanged: {
        if (visible) {
            const now = new Date();
            viewYear = now.getFullYear();
            viewMonth = now.getMonth();
            selKey = HolidayService.key(now);
            rebuild();
        } else {
            editing = false;
        }
    }

    // The cache lands asynchronously; restamp the grid when it does
    Connections {
        target: HolidayService
        function onDaysChanged() { panel.rebuild(); }
    }

    function rebuild() {
        const today = new Date();
        const first = new Date(viewYear, viewMonth, 1);
        const lead = (first.getDay() - firstDow + 7) % 7;
        const start = new Date(viewYear, viewMonth, 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            const k = HolidayService.key(d);
            const hs = HolidayService.forKey(k);
            out.push({
                day: d.getDate(),
                key: k,
                inMonth: d.getMonth() === viewMonth,
                today: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate(),
                hol: hs.length > 0,
                pub: hs.some(h => h.p)
            });
        }
        grid = out;
    }

    // "2026-08-15" -> Date, built from parts: Date("2026-08-15") parses as
    // UTC and would render as the wrong day west of Greenwich
    function keyToDate(k) {
        const p = k.split("-");
        return new Date(+p[0], +p[1] - 1, +p[2]);
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

    // Elapsed share of the period, counting time of day — subtracting the two
    // boundaries keeps leap years and DST shifts honest.
    function yearPct(d) {
        const s = new Date(d.getFullYear(), 0, 1);
        const e = new Date(d.getFullYear() + 1, 0, 1);
        return Math.round((d - s) / (e - s) * 100);
    }

    function monthPct(d) {
        const s = new Date(d.getFullYear(), d.getMonth(), 1);
        const e = new Date(d.getFullYear(), d.getMonth() + 1, 1);
        return Math.round((d - s) / (e - s) * 100);
    }

    function fmtTime(ts) {
        return Qt.formatDateTime(new Date(ts * 1000), "HH:mm");
    }

    PanelSurface { id: surf }

    Row {
        x: 18
        y: 14
        spacing: 18
        opacity: surf.opacity

        Column {
            id: calCol
            width: 266
            spacing: 4

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
                text: `Week ${panel.weekNumber(clock.date)} · Day ${panel.dayOfYear(clock.date)}`
                    + ` · Year ${panel.yearPct(clock.date)}% · Month ${panel.monthPct(clock.date)}%`
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
                        width: calCol.width / 7
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
                        id: cell
                        required property var modelData
                        readonly property bool selected: cell.modelData.key === panel.selKey
                        width: calCol.width / 7
                        height: 32

                        Rectangle {
                            y: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 26
                            height: 26
                            radius: Theme.radius
                            color: cell.modelData.today ? Theme.accent
                                : cell.selected ? Theme.surface : "transparent"
                            border.color: Theme.borderBright
                            border.width: cell.selected && !cell.modelData.today ? 1 : 0

                            Text {
                                anchors.centerIn: parent
                                text: cell.modelData.day
                                color: cell.modelData.today ? Theme.accentFg
                                    : cell.modelData.inMonth ? Theme.fg : Theme.faint
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.weight: cell.modelData.today
                                    ? Font.DemiBold : Font.Normal
                            }
                        }

                        // Marker for days carrying a holiday or observance
                        Rectangle {
                            visible: cell.modelData.hol
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 28
                            width: 4
                            height: 4
                            radius: 2
                            opacity: cell.modelData.inMonth ? 1 : 0.4
                            color: cell.modelData.today ? Theme.accentFg
                                : cell.modelData.pub ? Theme.accent : Theme.muted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.selKey = cell.modelData.key
                        }
                    }
                }
            }

            Item { width: 1; height: 10 }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Item { width: 1; height: 4 }

            // Holidays and observances for the selected day
            Text {
                text: Qt.formatDate(panel.keyToDate(panel.selKey), "dddd, d MMMM")
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }

            Item { width: 1; height: 4 }

            Text {
                visible: panel.selEvents.length === 0
                text: "Nothing on this day"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 12
            }

            Repeater {
                model: panel.selEvents

                Item {
                    id: evRow
                    required property var modelData
                    width: calCol.width
                    height: 20

                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        x: 1
                        width: 5
                        height: 5
                        radius: 2.5
                        color: evRow.modelData.p ? Theme.accent : Theme.muted
                    }

                    Text {
                        anchors.left: dot.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: evRow.modelData.n
                        elide: Text.ElideRight
                        color: evRow.modelData.p ? Theme.fg : Theme.dim
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: evRow.modelData.p ? Font.Medium : Font.Normal
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: Math.max(calCol.implicitHeight, wxCol.implicitHeight)
            color: Theme.line
        }

        Column {
            id: wxCol
            width: 264
            spacing: 4

            Item {
                width: parent.width
                height: 20
                // Esc: cancel edit first, then close; also catches stray keys
                Keys.onEscapePressed: {
                    if (panel.editing)
                        panel.editing = false;
                    else
                        ShellState.closePanels();
                }
                focus: !panel.editing

                Text {
                    visible: !panel.editing
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: (WeatherService.city || "Weather")
                        + (WeatherService.country ? ", " + WeatherService.country : "")
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                }

                ColorIcon {
                    visible: !panel.editing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "document-edit-symbolic"
                    size: 13
                    tint: editMouse.containsMouse ? Theme.fg : Theme.muted

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.editing = true;
                            cityIn.text = WeatherService.cityPref;
                            cityIn.forceActiveFocus();
                        }
                    }
                }

                Rectangle {
                    visible: panel.editing
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: cityIn.activeFocus ? Theme.borderBright : Theme.border
                    border.width: 1

                    TextInput {
                        id: cityIn
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        clip: true
                        onAccepted: {
                            WeatherService.setCity(text);
                            panel.editing = false;
                        }
                        Keys.onEscapePressed: panel.editing = false

                        Text {
                            visible: cityIn.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "City name — empty = auto-detect"
                            color: Theme.faint
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            Item {
                width: parent.width
                height: 46

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(WeatherService.temp) + "°C"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                }

                ColorIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: WeatherService.iconFor()
                    size: 34
                }
            }

            Text {
                text: {
                    const s = WeatherService.desc;
                    return s ? s.charAt(0).toUpperCase() + s.slice(1) : "";
                }
                color: Theme.dim
                font.family: Theme.uiFont
                font.pixelSize: 13
            }

            Item { width: 1; height: 8 }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Item { width: 1; height: 8 }

            Repeater {
                model: {
                    if (!panel.d)
                        return [];
                    const d = panel.d;
                    const rows = [];
                    const add = (k, v) => rows.push({ k: k, v: v });
                    add("Feels like", Math.round(d.main.feels_like) + "°C");
                    {
                        const mm = d.rain?.["1h"] ?? d.snow?.["1h"] ?? 0;
                        add("Precipitation", mm > 0
                            ? mm.toFixed(1) + " mm/h" + (d.snow ? " (snow)" : "")
                            : "None");
                    }
                    add("Humidity", d.main.humidity + "%");
                    if (d.wind)
                        add("Wind", Math.round(d.wind.speed * 3.6) + " km/h");
                    add("Pressure", d.main.pressure + " hPa");
                    if (d.visibility !== undefined)
                        add("Visibility", (d.visibility / 1000).toFixed(1) + " km");
                    if (d.sys)
                        add("Sunrise / sunset",
                            panel.fmtTime(d.sys.sunrise) + " / " + panel.fmtTime(d.sys.sunset));
                    return rows;
                }

                Item {
                    required property var modelData
                    width: wxCol.width
                    height: 22

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.k
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.v
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }
            }

            Item { width: 1; height: 8 }

            Rectangle {
                visible: WeatherService.forecast.length > 0
                width: parent.width
                height: 1
                color: Theme.line
            }

            Item { visible: WeatherService.forecast.length > 0; width: 1; height: 8 }

            Row {
                visible: WeatherService.forecast.length > 0

                Repeater {
                    model: WeatherService.forecast

                    Column {
                        required property var modelData
                        width: wxCol.width / Math.max(1, WeatherService.forecast.length)
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.day
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }

                        ColorIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon
                            size: 18
                        }

                        // max/min on one line: colour and weight carry the
                        // hierarchy now that size can't
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 1

                            Text {
                                text: modelData.max + "°"
                                color: Theme.fg
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Text {
                                text: "/"
                                color: Theme.faint
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.min + "°"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: modelData.pop >= 20
                            text: modelData.pop + "%"
                            color: Theme.dim
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

            Text {
                text: WeatherService.updatedAt > 0
                    ? "Updated " + Qt.formatDateTime(new Date(WeatherService.updatedAt), "HH:mm")
                    : "Waiting for data…"
                color: Theme.faint
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
    }
}
