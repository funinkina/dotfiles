pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    readonly property var all: server.trackedNotifications.values
    property var popups: []
    property bool paused: false

    PersistentProperties {
        id: store
        reloadableId: "notifService"
        property bool dndManual: false
    }

    readonly property bool dnd: store.dndManual || PrivacyService.screen
    readonly property bool dndForced: PrivacyService.screen

    function toggleDnd() { store.dndManual = !dnd; }
    function setDnd(on) { store.dndManual = on; }

    onDndChanged: if (dnd) popups = []

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            if (!root.dnd)
                root.popups = root.popups.concat([{ n: n, t: Date.now() }]);
        }
    }

    onAllChanged: popups = popups.filter(p => all.includes(p.n))

    Timer {
        interval: 500
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
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

    function buttons(n) {
        const a = [...n.actions];
        return n.hasActionIcons ? a : a.filter(x => x.identifier !== "default");
    }

    function activate(n) {
        const d = n.hasActionIcons
            ? undefined : [...n.actions].find(x => x.identifier === "default");
        if (d)
            d.invoke();
        else
            n.dismiss();
    }

    function themeName(s) {
        const prefix = "image://icon/";
        if (s.startsWith(prefix))
            return decodeURIComponent(s.slice(prefix.length));
        return s.startsWith("/") || s.includes("://") ? "" : s;
    }

    function fileUrl(s) {
        return s.startsWith("/")
            ? "file://" + s.split("/").map(encodeURIComponent).join("/") : s;
    }

    function cardImage(n) {
        const raw = n.image || n.appIcon;
        if (!raw)
            return "";
        const name = themeName(raw);
        if (!name)
            return fileUrl(raw); 
        return Quickshell.iconPath(name, true)
            || (n.desktopEntry ? Quickshell.iconPath(n.desktopEntry, true) : "");
    }
    function appGlyph(n) {
        const raw = n.appIcon || n.image;
        const name = themeName(raw);
        if (!name && n.appIcon)
            return { path: fileUrl(n.appIcon), symbolic: false };
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
