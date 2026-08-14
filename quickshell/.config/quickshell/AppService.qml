pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The app model behind both the dock and the launcher: which apps are pinned
// and in what order, how often each has been launched, and search over the
// desktop entries.
//
// State lives in ~/.local/state, not the config dir — that one is a stow
// symlink into the dotfiles repo, so writing pins there would dirty the repo
// every time an icon is dragged.
Singleton {
    id: root

    readonly property string stateDir: "/home/funinkina/.local/state/quickshell"
    readonly property string statePath: stateDir + "/apps.json"

    // Seeds the file on first run: the list the dock used to hardcode.
    readonly property var defaultPins: [
        "helium",
        "org.gnome.Nautilus",
        "chrome-cinhimbnkkaeohfgghhklpknlkffjgod-Default",
        "kitty",
        "code",
        "dev.zed.Zed",
        "chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Default",
        "slack",
        "org.gnome.Geary",
        "figma-linux-next",
        "io.github.tanaybhomia.Whisp",
        "ChatGPT",
        "org.gnome.TextEditor",
        "net.nokyan.Resources",
        "google-chrome",
        "org.gnome.Calculator"
    ]

    property var pinned: defaultPins
    property var counts: ({})
    // Guards against writing defaults over a file that hasn't been read yet.
    property bool loaded: false

    function norm(s) { return (s ?? "").toLowerCase(); }

    // ---- persistence ----

    // The state dir may not exist yet. FileView can't create it, so this does;
    // the load that failed before it ran is retried on exit.
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
        onExited: store.reload()
    }

    FileView {
        id: store
        path: root.statePath
        preload: true
        watchChanges: true
        printErrors: false   // a missing file on first run is expected
        onFileChanged: reload()
        onLoaded: root.adopt(store.text())
        onLoadFailed: {
            root.loaded = true;
            root.save();
        }
    }

    function adopt(txt) {
        try {
            const j = JSON.parse(txt);
            if (Array.isArray(j.pinned))
                pinned = j.pinned.filter(p => typeof p === "string");
            if (j.counts && typeof j.counts === "object")
                counts = j.counts;
        } catch (e) {
            // Corrupt file: keep whatever is in memory and rewrite it below.
        }
        loaded = true;
    }

    function save() {
        if (!loaded)
            return;
        store.setText(JSON.stringify({ pinned: pinned, counts: counts }, null, 2));
    }

    // ---- pins ----

    function isPinned(id) {
        const k = norm(id);
        return pinned.some(p => norm(p) === k);
    }

    function pin(id) {
        if (!id || isPinned(id))
            return;
        pinned = pinned.concat([id]);
        save();
    }

    function unpin(id) {
        const k = norm(id);
        pinned = pinned.filter(p => norm(p) !== k);
        save();
    }

    function move(from, to) {
        if (from < 0 || from >= pinned.length || from === to)
            return;
        const a = pinned.slice();
        const [item] = a.splice(from, 1);
        a.splice(Math.max(0, Math.min(a.length, to)), 0, item);
        pinned = a;
        save();
    }

    // ---- windows ----

    // Lowercase window app_id -> the pin it belongs to. A window's app_id is
    // usually the entry id, but StartupWMClass is the field that actually
    // declares it, so both are indexed. Built once per pin-list change rather
    // than rescanning the entry list per window.
    readonly property var pinKeys: {
        const m = {};
        for (const p of pinned) {
            m[norm(p)] = p;
            const cls = norm(NiriService.entryFor(p)?.startupClass ?? "");
            if (cls)
                m[cls] = p;
        }
        return m;
    }

    // The pin a window belongs to, or null when it belongs to none.
    function pinOwning(w) { return pinKeys[norm(w?.app_id)] ?? null; }

    function windowsFor(id) {
        const k = norm(id);
        const cls = norm(NiriService.entryFor(id)?.startupClass ?? "");
        return Object.values(NiriService.windows)
            .filter(w => {
                const a = norm(w.app_id);
                return a === k || (cls !== "" && a === cls);
            })
            .sort((a, b) => a.id - b.id);
    }

    // Most recently focused window of an app — the one a "focus" action means.
    function topWindow(id) {
        return windowsFor(id).sort(
            (a, b) => (b.focus_timestamp ?? 0) - (a.focus_timestamp ?? 0))[0] ?? null;
    }

    // ---- launching ----

    function bump(id) {
        if (!id)
            return;
        const c = Object.assign({}, counts);
        c[id] = (c[id] ?? 0) + 1;
        counts = c;
        save();
    }

    function launchEntry(entry, workspace) {
        if (!entry)
            return;
        // niri has no "spawn on workspace", so focus it first. Both are
        // fire-and-forget, but a workspace switch lands in microseconds and an
        // app takes far longer to map its first window, so the order holds.
        if (workspace !== undefined && workspace !== null && workspace !== "")
            NiriService.dispatch(["focus-workspace", String(workspace)]);
        entry.execute();
        bump(entry.id);
    }

    function launch(id, workspace) {
        launchEntry(NiriService.entryFor(id), workspace);
    }

    // ---- search ----

    readonly property var entries: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)

    function launchCount(e) { return counts[e?.id ?? ""] ?? 0; }

    // Every character of the query in order, not necessarily adjacent —
    // the last-resort match so "gimp" still finds "GNU Image Manipulation".
    function subseq(s, q) {
        let i = 0;
        for (let c = 0; c < s.length; c++)
            if (s[c] === q[i] && ++i === q.length)
                return true;
        return false;
    }

    // Higher is a better match. Name hits beat metadata hits; within a tier
    // an earlier, tighter match wins.
    function score(e, q) {
        const n = norm(e.name);
        if (n === q) return 100;
        if (n.startsWith(q)) return 90;
        if (n.split(/[\s\-_]+/).some(w => w.startsWith(q))) return 80;
        if (n.includes(q)) return 70;
        if (norm(e.genericName).includes(q)) return 60;
        if (norm((e.keywords ?? []).join(" ")).includes(q)) return 50;
        if (norm(e.comment).includes(q)) return 40;
        if (norm(e.id).includes(q)) return 30;
        if (norm(e.execString).includes(q)) return 20;
        return subseq(n, q) ? 10 : 0;
    }

    // Empty query lists everything, most-launched first — the grid is a
    // frequency ranking, not an alphabet.
    function search(query) {
        const q = norm(query).trim();
        const byName = (a, b) => (a.name ?? "").localeCompare(b.name ?? "");
        if (q === "")
            return entries.slice().sort(
                (a, b) => launchCount(b) - launchCount(a) || byName(a, b));
        return entries
            .map(e => ({ e: e, s: score(e, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s
                || launchCount(b.e) - launchCount(a.e)
                || byName(a.e, b.e))
            .map(x => x.e);
    }
}
