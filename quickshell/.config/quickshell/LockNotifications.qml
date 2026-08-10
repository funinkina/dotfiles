import QtQuick

// Lock-screen notifications: who they're from, never what they say.
// Summary, body and any attached image are all withheld, and there are no
// click targets — nothing here should be reachable while the session is locked.
Column {
    id: root

    // Newest first, collapsed per app so twenty messages aren't twenty cards.
    readonly property var groups: {
        const out = [];
        for (const n of [...NotifService.all].reverse()) {
            const g = out.find(x => x.n.appName === n.appName);
            if (g)
                g.count++;
            else
                out.push({ n: n, count: 1 });
        }
        return out;
    }
    readonly property int limit: 5

    spacing: 8
    visible: groups.length > 0

    Repeater {
        model: root.groups.slice(0, root.limit)

        Rectangle {
            id: card
            required property var modelData
            width: 300
            implicitHeight: row.implicitHeight + 22
            radius: Theme.panelRadius
            color: Theme.barBg
            border.color: Theme.border
            border.width: 1

            Row {
                id: row
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                AppGlyph {
                    notification: card.modelData.n
                    size: 16
                    tint: Theme.dim
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 26
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: card.modelData.n.appName || "Notification"
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: card.modelData.count === 1
                            ? "1 notification hidden"
                            : `${card.modelData.count} notifications hidden`
                        color: Theme.faint
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        text: `+${root.groups.length - root.limit} more`
        visible: root.groups.length > root.limit
        color: Theme.dim
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
}
