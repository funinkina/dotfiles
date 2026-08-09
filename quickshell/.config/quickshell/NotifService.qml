pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Owns the notification server. Notifications stay tracked (for the
// notification center) until dismissed; `popups` only controls the
// transient top-center popup.
Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var popups: []   // [{ n: notification, t: arrival ms }]

    NotificationServer {
        id: server
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            root.popups = root.popups.concat([{ n: n, t: Date.now() }]);
        }
    }

    // Drop popup entries whose notification was dismissed/closed
    onAllChanged: popups = popups.filter(p => all.includes(p.n))

    // Age out popups; critical ones stay until dismissed
    Timer {
        interval: 500
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const now = Date.now();
            root.popups = root.popups.filter(p =>
                p.n.urgency === NotificationUrgency.Critical || now - p.t < 6000);
        }
    }

    function dismissAll() {
        for (const n of [...all])
            n.dismiss();
    }
}
