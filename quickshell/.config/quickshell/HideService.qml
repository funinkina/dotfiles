pragma Singleton
import Quickshell
import QtQuick

// Window hiding ("minimize"): hidden windows are parked on a runtime-named
// "hidden" workspace (named at runtime so it never claims idx 1 and breaks
// Mod+1..9). They stay visible in the dock / switchers / overview; focusing
// a hidden window from anywhere restores it to its original workspace.
Singleton {
    id: root

    PersistentProperties {
        id: store
        reloadableId: "hideService"
        property var hiddenOrig: ({})   // windowId -> original workspace idx
    }

    readonly property var hiddenWs:
        NiriService.workspaces.find(w => w.name === "hidden") ?? null

    property var pending: []

    function hideActive() {
        if (NiriService.focusedWindowId !== null)
            hideWindow(NiriService.focusedWindowId);
    }

    function hideWindow(id) {
        const win = NiriService.windows[id];
        if (!win)
            return;
        const ws = NiriService.workspaces.find(w => w.id === win.workspace_id);
        if (!ws || ws.name === "hidden")
            return;
        const m = Object.assign({}, store.hiddenOrig);
        m[id] = ws.idx;
        store.hiddenOrig = m;
        if (hiddenWs) {
            moveToHidden(id);
        } else {
            // Name the last (empty) workspace "hidden", then move after it lands
            const last = Math.max(...NiriService.workspaces.map(w => w.idx));
            NiriService.dispatch(["set-workspace-name", "--workspace", String(last), "hidden"]);
            pending = pending.concat([id]);
            pendTimer.restart();
        }
    }

    function moveToHidden(id) {
        NiriService.dispatch(["move-window-to-workspace",
            "--window-id", String(id), "--focus", "false", "hidden"]);
    }

    Timer {
        id: pendTimer
        interval: 250
        onTriggered: {
            for (const id of root.pending)
                root.moveToHidden(id);
            root.pending = [];
        }
    }

    function restoreWindow(id) {
        const idx = store.hiddenOrig[id];
        if (idx === undefined)
            return;
        const m = Object.assign({}, store.hiddenOrig);
        delete m[id];
        store.hiddenOrig = m;
        NiriService.dispatch(["move-window-to-workspace",
            "--window-id", String(id), String(idx)]);
        focusTimer.windowId = id;
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        property int windowId: -1
        interval: 150
        onTriggered: NiriService.dispatch(["focus-window", "--id", String(windowId)])
    }

    function toggleAll() {
        if (Object.keys(store.hiddenOrig).length > 0) {
            for (const id of Object.keys(store.hiddenOrig))
                restoreWindow(parseInt(id));
        } else {
            const ws = NiriService.workspaces.find(w => w.is_focused);
            if (!ws)
                return;
            for (const win of Object.values(NiriService.windows))
                if (win.workspace_id === ws.id)
                    hideWindow(win.id);
        }
    }

    // Focusing a hidden window (dock, switcher, overview) restores it
    Connections {
        target: NiriService
        function onFocusedWindowIdChanged() {
            const id = NiriService.focusedWindowId;
            if (id !== null && store.hiddenOrig[id] !== undefined)
                root.restoreWindow(id);
        }
        function onWindowsChanged() {
            root.cleanup();
        }
    }

    // Drop the named workspace once nothing is hidden anymore
    function cleanup() {
        if (!hiddenWs)
            return;
        // Forget entries for windows that no longer exist
        const m = Object.assign({}, store.hiddenOrig);
        let changed = false;
        for (const id of Object.keys(m))
            if (!NiriService.windows[id]) {
                delete m[id];
                changed = true;
            }
        if (changed)
            store.hiddenOrig = m;
        if (Object.keys(m).length === 0
                && !Object.values(NiriService.windows).some(
                    w => w.workspace_id === hiddenWs.id))
            NiriService.dispatch(["unset-workspace-name", "hidden"]);
    }
}
