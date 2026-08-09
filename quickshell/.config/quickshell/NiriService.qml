pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var focusedWindowId: null
    property var casts: []
    readonly property var focusedWindow: focusedWindowId !== null
        ? (windows[focusedWindowId] ?? null) : null

    function dispatch(args) {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    // Reactive lookup: reading applications.values makes QML bindings
    // re-evaluate once the (async) desktop entry list loads.
    function entryFor(id) {
        const apps = DesktopEntries.applications.values;
        const lid = (id ?? "").toLowerCase();
        return apps.find(a => a.id.toLowerCase() === lid)
            ?? apps.find(a => (a.name ?? "").toLowerCase() === lid)
            ?? null;
    }

    function appInfo(w) {
        if (!w)
            return { name: "", icon: "" };
        const id = w.app_id ?? "";
        const entry = entryFor(id);
        const isPwa = id.startsWith("chrome-") && id.endsWith("-Default");
        const name = entry?.name
            ?? (isPwa ? (w.title ?? "Web App").slice(0, 25)
                      : (id.split(".").pop() || "?"));
        return { name: name, icon: entry?.icon ?? "application-x-executable" };
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let ev;
                try { ev = JSON.parse(data); } catch (e) { return; }

                if (ev.WorkspacesChanged) {
                    root.workspaces = ev.WorkspacesChanged.workspaces
                        .slice().sort((a, b) => a.idx - b.idx);
                } else if (ev.WorkspaceActivated) {
                    const id = ev.WorkspaceActivated.id;
                    const target = root.workspaces.find(w => w.id === id);
                    if (!target) return;
                    root.workspaces = root.workspaces.map(w => {
                        const c = Object.assign({}, w);
                        if (w.output === target.output)
                            c.is_active = (w.id === id);
                        if (ev.WorkspaceActivated.focused)
                            c.is_focused = (w.id === id);
                        return c;
                    });
                } else if (ev.WorkspaceUrgencyChanged) {
                    root.workspaces = root.workspaces.map(w =>
                        w.id === ev.WorkspaceUrgencyChanged.id
                            ? Object.assign({}, w, { is_urgent: ev.WorkspaceUrgencyChanged.urgent })
                            : w);
                } else if (ev.WindowsChanged) {
                    const m = {};
                    for (const w of ev.WindowsChanged.windows) {
                        m[w.id] = w;
                        if (w.is_focused)
                            root.focusedWindowId = w.id;
                    }
                    root.windows = m;
                } else if (ev.WindowOpenedOrChanged) {
                    const w = ev.WindowOpenedOrChanged.window;
                    const m = Object.assign({}, root.windows);
                    m[w.id] = w;
                    root.windows = m;
                    if (w.is_focused)
                        root.focusedWindowId = w.id;
                } else if (ev.WindowClosed) {
                    const m = Object.assign({}, root.windows);
                    delete m[ev.WindowClosed.id];
                    root.windows = m;
                    if (root.focusedWindowId === ev.WindowClosed.id)
                        root.focusedWindowId = null;
                } else if (ev.WindowFocusChanged) {
                    root.focusedWindowId = ev.WindowFocusChanged.id ?? null;
                } else if (ev.CastsChanged) {
                    root.casts = ev.CastsChanged.casts;
                } else if (ev.CastStartedOrChanged) {
                    const c = ev.CastStartedOrChanged.cast;
                    root.casts = root.casts.filter(x => x.id !== c.id).concat([c]);
                } else if (ev.CastStopped) {
                    root.casts = root.casts.filter(x => x.id !== ev.CastStopped.id);
                }
            }
        }
    }
}
