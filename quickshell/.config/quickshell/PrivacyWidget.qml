import QtQuick
import QtQuick.Layouts

// Privacy indicators: shown only while the camera / mic / screenshare is live.
Item {
    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barHeight
    visible: PrivacyService.mic || PrivacyService.cam || PrivacyService.screen

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 10

        ColorIcon {
            visible: PrivacyService.cam
            name: "camera-web-symbolic"
            size: 15
            tint: Theme.urgent
            Layout.alignment: Qt.AlignVCenter
        }

        ColorIcon {
            visible: PrivacyService.mic
            name: "audio-input-microphone-symbolic"
            size: 15
            tint: Theme.urgent
            Layout.alignment: Qt.AlignVCenter
        }

        ColorIcon {
            visible: PrivacyService.screen
            name: "screen-shared-symbolic"
            size: 15
            tint: Theme.urgent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
