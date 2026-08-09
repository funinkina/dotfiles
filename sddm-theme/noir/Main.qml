import QtQuick
import QtQuick.Controls.Basic
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    color: "#000000"

    readonly property color fg: "#e6e6e6"
    readonly property color mutedC: "#8a8a8a"
    readonly property color faintC: "#555555"
    readonly property color borderC: "#4d4d4d"
    readonly property color urgentC: "#f2555a"
    readonly property string uiFont: "SF Pro Text"

    property date now: new Date()

    // Resolve the last user's real (full) name from the user model
    property string realName: ""
    Repeater {
        model: userModel
        Item {
            required property var model
            Component.onCompleted: {
                if (model.name === userModel.lastUser && model.realName)
                    root.realName = model.realName;
            }
        }
    }

    Image {
        anchors.fill: parent
        source: "background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    // Dim so the login elements stay legible
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.6
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            status.text = "Incorrect password";
            pw.text = "";
            pw.forceActiveFocus();
        }
    }

    Component.onCompleted: pw.forceActiveFocus()

    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.33 - height / 2
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.fg
            font.family: root.uiFont
            font.pixelSize: 108
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: root.fg
            font.family: root.uiFont
            font.pixelSize: 20
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 10

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76

            Image {
                id: avatar
                anchors.fill: parent
                source: "/var/lib/AccountsService/icons/" + userModel.lastUser
                fillMode: Image.PreserveAspectCrop
                visible: status !== Image.Error
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 76
                        height: 76
                        radius: 38
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 38
                visible: avatar.status === Image.Error
                color: "#141414"
                border.color: root.borderC
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: userModel.lastUser.charAt(0).toUpperCase()
                    color: root.fg
                    font.family: root.uiFont
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.realName || userModel.lastUser || "User"
            color: root.fg
            font.family: root.uiFont
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.realName !== "" && userModel.lastUser !== ""
            text: userModel.lastUser
            color: root.mutedC
            font.family: root.uiFont
            font.pixelSize: 12
        }

        Item { width: 1; height: 12 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 34
            color: "#0d0d0d"
            border.color: pw.activeFocus ? root.fg : root.borderC
            border.width: 1

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 14
                clip: true
                onAccepted: sddm.login(userModel.lastUser, text, session.currentIndex)

                Text {
                    visible: pw.text === "" && !pw.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    color: root.faintC
                    font.family: root.uiFont
                    font.pixelSize: 14
                }
            }
        }

        Text {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            visible: text !== ""
            color: root.urgentC
            font.family: root.uiFont
            font.pixelSize: 13
        }
    }

    // Session picker, bottom left
    ComboBox {
        id: session
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        width: 180
        height: 34
        model: sessionModel
        textRole: "name"
        currentIndex: sessionModel.lastIndex
        font.family: root.uiFont
        font.pixelSize: 13

        background: Rectangle {
            color: "#0d0d0d"
            border.color: root.borderC
            border.width: 1
        }

        contentItem: Text {
            leftPadding: 12
            verticalAlignment: Text.AlignVCenter
            text: session.displayText
            color: root.fg
            font: session.font
        }

        popup: Popup {
            y: -implicitHeight - 4
            width: session.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            background: Rectangle {
                color: "#0d0d0d"
                border.color: root.borderC
                border.width: 1
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: session.popup.visible ? session.delegateModel : null
            }
        }

        delegate: ItemDelegate {
            required property var model
            required property int index
            width: session.width
            height: 30
            highlighted: session.highlightedIndex === index

            background: Rectangle {
                color: parent.highlighted ? "#1f1f1f" : "transparent"
            }

            contentItem: Text {
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                text: model.name
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 13
            }
        }
    }

    // Power controls + logo, bottom right
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 18

        Rectangle {
            width: rebootLabel.implicitWidth + 24
            height: 34
            color: rebootMouse.containsMouse ? "#1f1f1f" : "#0d0d0d"
            border.color: root.borderC
            border.width: 1
            visible: sddm.canReboot

            Text {
                id: rebootLabel
                anchors.centerIn: parent
                text: "Restart"
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 13
            }

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.reboot()
            }
        }

        Rectangle {
            width: powerLabel.implicitWidth + 24
            height: 34
            color: powerMouse.containsMouse ? "#1f1f1f" : "#0d0d0d"
            border.color: root.borderC
            border.width: 1
            visible: sddm.canPowerOff

            Text {
                id: powerLabel
                anchors.centerIn: parent
                text: "Shut Down"
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: 13
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sddm.powerOff()
            }
        }

        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "archlogo.svg"
            sourceSize.height: 80
            fillMode: Image.PreserveAspectFit
            opacity: 0.85
        }
    }
}
