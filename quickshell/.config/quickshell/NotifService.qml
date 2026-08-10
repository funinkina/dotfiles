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
    property bool paused: false   // hovering the popup stack freezes the countdown

    NotificationServer {
        id: server
        // Chromium refuses the D-Bus bridge unless the server advertises both
        // "body" and "actions", and falls back to its own notification windows.
        actionsSupported: true
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
            // Push arrival times along instead of aging, so a popup can't
            // expire out from under the pointer while its buttons are aimed at.
            if (root.paused) {
                for (const p of root.popups)
                    p.t += interval;
                return;
            }
            const now = Date.now();
            root.popups = root.popups.filter(p =>
                p.n.urgency === NotificationUrgency.Critical || now - p.t < 6000);
        }
    }

    function dismissAll() {
        for (const n of [...all])
            n.dismiss();
    }

    // Actions to draw as buttons. freedesktop reserves "default" for clicking
    // the notification itself, so it never gets one. When the sender supplies
    // action icons the identifier is an icon name and the rule doesn't apply.
    function buttons(n) {
        const a = [...n.actions];
        return n.hasActionIcons ? a : a.filter(x => x.identifier !== "default");
    }

    // Clicking the card body. invoke() closes the notification on its own
    // unless it is resident, so don't dismiss on top of it.
    function activate(n) {
        const d = n.hasActionIcons
            ? undefined : [...n.actions].find(x => x.identifier === "default");
        if (d)
            d.invoke();
        else
            n.dismiss();
    }

    // The sender's icon for the header row. Prefers the icon theme's symbolic
    // variant; reports which one it found so the caller knows whether flat
    // tinting is safe (tinting a full-color logo just yields a silhouette).
    function appGlyph(n) {
        if (n.appIcon.startsWith("/") || n.appIcon.includes("://"))
            return { path: n.appIcon, symbolic: false };
        for (const c of [n.desktopEntry, n.appIcon]) {
            const p = c ? Quickshell.iconPath(c + "-symbolic", true) : "";
            if (p)
                return { path: p, symbolic: true };
        }
        for (const c of [n.appIcon, n.desktopEntry]) {
            const p = c ? Quickshell.iconPath(c, true) : "";
            if (p)
                return { path: p, symbolic: false };
        }
        return { path: Quickshell.iconPath("application-x-executable-symbolic", true), symbolic: true };
    }
}
