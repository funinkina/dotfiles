import QtQuick

// Thin grey line separating the bar from an attached popout, 90% width.
Rectangle {
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width * 0.9
    height: 1
    color: "#333333"
}
