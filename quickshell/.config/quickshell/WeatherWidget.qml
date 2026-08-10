import QtQuick
import Quickshell
import QtQuick.Layouts

// Bar weather: condition icon + temperature.
Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight
    visible: WeatherService.data !== null

    HoverBg {}

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

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

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        onClicked: {
            WeatherService.refresh();
            ShellState.togglePanel("weather", QsWindow.window?.screen?.name ?? "");
        }
    }
}
