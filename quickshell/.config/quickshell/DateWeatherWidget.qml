import QtQuick
import QtQuick.Layouts
import Quickshell

// Bar item: date + time, with the current conditions riding along.
// One hover target, one panel — the calendar popout carries both.
Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverBg {
        active: ShellState.isOpen("clock", QsWindow.window?.screen?.name ?? "")
        pressed: ma.pressed
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

        // Collapses until the first fetch lands
        RowLayout {
            visible: WeatherService.data !== null
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            ColorIcon {
                name: WeatherService.iconFor()
                size: 16
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: Math.round(WeatherService.temp) + "°"
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSize
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            WeatherService.refresh();
            ShellState.togglePanel("clock", QsWindow.window?.screen?.name ?? "");
        }
    }
}
