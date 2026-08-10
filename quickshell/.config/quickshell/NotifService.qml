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

    // Icons reach us three ways: a bare theme name, an absolute path, or a
    // pre-formed image://icon/<name> url (that's what notify-send's -i becomes,
    // and it lands in `image` with `appIcon` left empty). Recover the theme name
    // from the first and last forms; "" means it isn't a themed icon at all.
    function themeName(s) {
        const prefix = "image://icon/";
        if (s.startsWith(prefix))
            return decodeURIComponent(s.slice(prefix.length));
        return s.startsWith("/") || s.includes("://") ? "" : s;
    }

    // Large icon for the card: the notification's own image if it has one,
    // else the app icon. Themed names are checked for existence, because an
    // unresolvable one paints Qt's magenta missing-image checkerboard rather
    // than nothing. Returns "" so the slot can collapse instead.
    function cardImage(n) {
        const raw = n.image || n.appIcon;
        if (!raw)
            return "";
        const name = themeName(raw);
        if (!name)
            return raw;   // a real file, or an image the sender embedded
        return Quickshell.iconPath(name, true)
            || (n.desktopEntry ? Quickshell.iconPath(n.desktopEntry, true) : "");
    }

    // The sender's icon for the header row. Prefers the icon theme's symbolic
    // variant; reports which one it found so the caller knows whether flat
    // tinting is safe (tinting a full-color logo just yields a silhouette).
    function appGlyph(n) {
        const raw = n.appIcon || n.image;
        const name = themeName(raw);
        // A path here is the app's own icon file; an embedded image is the
        // notification's content (a contact photo), which is not the app.
        if (!name && n.appIcon)
            return { path: n.appIcon, symbolic: false };
        for (const c of [n.desktopEntry, name]) {
            const p = c ? Quickshell.iconPath(c + "-symbolic", true) : "";
            if (p)
                return { path: p, symbolic: true };
        }
        for (const c of [name, n.desktopEntry]) {
            const p = c ? Quickshell.iconPath(c, true) : "";
            if (p)
                return { path: p, symbolic: false };
        }
        return { path: Quickshell.iconPath("application-x-executable-symbolic", true), symbolic: true };
    }
}
