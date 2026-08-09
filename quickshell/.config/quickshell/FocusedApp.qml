import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    visible: NiriService.focusedWindow !== null

    readonly property var info: NiriService.appInfo(NiriService.focusedWindow)

    HoverBg {}

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 8

        // Real app icon from the icon theme (color, per-app)
        IconImage {
            source: root.info.icon ? Quickshell.iconPath(root.info.icon, "application-x-executable") : ""
            implicitSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.info.name
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            readonly property string title: NiriService.focusedWindow?.title ?? ""
            text: title
            visible: title.length > 0 && title !== root.info.name
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            Layout.maximumWidth: 480
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
