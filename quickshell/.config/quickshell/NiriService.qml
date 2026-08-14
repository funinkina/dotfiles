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
    // The window the shell should treat as current. niri reports no focused
    // window while one of our own layer surfaces holds the keyboard — which is
    // every open panel — so fall back to the focused workspace's active
    // window. That is still the window the user is on; clicking a bar widget
    // shouldn't make the bar forget it. A genuinely empty workspace yields null.
    readonly property var activeWindowId: {
        if (focusedWindowId !== null && windows[focusedWindowId])
            return focusedWindowId;
        const ws = workspaces.find(w => w.is_focused);
        const id = ws?.active_window_id ?? null;
        return id !== null && windows[id] ? id : null;
    }

    readonly property var focusedWindow: activeWindowId !== null
        ? (windows[activeWindowId] ?? null) : null

    // Connector name of the monitor the user is on — what a keybind-triggered
    // panel should open on when the bind carries no screen of its own.
    readonly property string focusedOutput:
        workspaces.find(w => w.is_focused)?.output ?? ""

    function dispatch(args) {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    // Focus the best window for a loose app key. Tray ids carry suffixes
    // ("Slack_status_icon_1"), so fall back to the leading token; among several
    // windows of one app the most recently focused wins. Returns false when
    // nothing matches — an app that minimised to its tray icon has no window.
    function focusApp(key) {
        const k = (key ?? "").toLowerCase();
        if (!k)
            return false;
        const base = k.split(/[_\-. ]/)[0];
        const appId = w => (w.app_id ?? "").toLowerCase();
        const wins = Object.values(windows).sort(
            (a, b) => (b.focus_timestamp ?? 0) - (a.focus_timestamp ?? 0));
        const w = wins.find(x => appId(x) === k)
            ?? wins.find(x => appId(x) === base)
            ?? (base.length >= 3 ? wins.find(x => appId(x).startsWith(base)) : undefined);
        if (!w)
            return false;
        dispatch(["focus-window", "--id", String(w.id)]);
        return true;
    }

    function isFullscreen(output, outputHeight) {
        const ws = workspaces.find(w => w.output === output && w.is_active);
        const win = ws ? windows[ws.active_window_id] : null;
        return !!win && !win.is_floating && outputHeight > 0
            && Math.abs((win.layout?.tile_size?.[1] ?? 0) - outputHeight) < 2;
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
                } else if (ev.WindowLayoutsChanged) {
                    // Resizes (incl. fullscreen) arrive here, not as WindowOpenedOrChanged
                    const m = Object.assign({}, root.windows);
                    for (const [id, layout] of ev.WindowLayoutsChanged.changes)
                        if (m[id])
                            m[id] = Object.assign({}, m[id], { layout: layout });
                    root.windows = m;
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
