import Quickshell
import Quickshell.Wayland
import QtQuick

// Weather popout: location, conditions, and details.
PanelWindow {
    id: panel
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-weather"
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool editing: false
    onVisibleChanged: if (!visible) editing = false

    readonly property string sname: screen?.name ?? ""
    visible: ShellState.openPanel === "weather" && ShellState.panelScreen === sname

    anchors { top: true; right: true }
    margins {
        top: Theme.barHeight + 8
        right: {
            const ax = ShellState.anchorMap[sname]?.weather ?? -1;
            return ax < 0 ? 16
                : Math.max(8, (screen?.width ?? 1920) - ax - implicitWidth / 2);
        }
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    readonly property var d: WeatherService.data

    function fmtTime(ts) {
        return Qt.formatDateTime(new Date(ts * 1000), "HH:mm");
    }

    PanelSurface { id: surf }

    Column {
        id: col
        x: 18
        y: 14
        width: parent.width - 36
        spacing: 4
        opacity: surf.opacity

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
                width: col.width
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
                    width: col.width / Math.max(1, WeatherService.forecast.length)
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

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.max + "°"
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.min + "°"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 11
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
