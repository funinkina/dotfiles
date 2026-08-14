pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string thumbDir: "/home/funinkina/.cache/quickshell/clipthumbs"
    readonly property string thumbScript:
        "/home/funinkina/.config/quickshell/scripts/clipthumbs.sh"

    property var entries: []
    property var pending: []

    function refresh() {
        if (!listProc.running && !thumbProc.running)
            listProc.running = true;
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function describe(blob) {
        const p = blob.split(/\s+/);
        const out = [];
        if (p.length >= 2)
            out.push(p[0] + " " + p[1]);
        if (p.length >= 3)
            out.push(p[2]);
        if (p.length >= 4)
            out.push(p[3].replace("x", "×"));
        return out.length > 0 ? out.join(" · ") : blob;
    }

    function parse(out) {
        const binary = /^\[\[\s*binary data\s+(.*?)\s*\]\]$/;
        const list = [];
        const imageIds = [];
        for (const line of out.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;
            const id = line.slice(0, tab);
            const preview = line.slice(tab + 1);
            const m = binary.exec(preview);
            if (m) {
                imageIds.push(id);
                list.push({
                    id: id, line: line, image: true,
                    text: "Image", meta: describe(m[1]),
                    thumb: "file://" + root.thumbDir + "/" + id
                });
            } else {
                list.push({
                    id: id, line: line, image: false,
                    text: preview, meta: "", thumb: ""
                });
            }
        }
        pending = list;
        thumbProc.command = ["sh", root.thumbScript, root.thumbDir].concat(imageIds);
        thumbProc.running = true;
    }

    Process {
        id: thumbProc
        onExited: {
            root.entries = root.pending;
            root.pending = [];
        }
    }

    function remove(entry) {
        if (!entry)
            return;
        delProc.command = ["sh", "-c", 'printf %s "$0" | cliphist delete', entry.line];
        delProc.running = true;
    }

    Process {
        id: delProc
        onExited: root.refresh()
    }

    function wipe() {
        wipeProc.running = true;
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    readonly property var ctrlVTerminals: ["kitty"]

    function paste(entry) {
        if (!entry)
            return;

        const app = (NiriService.focusedWindow?.app_id ?? "").toLowerCase();
        pasteTimer.viaTerminal = entry.image && ctrlVTerminals.includes(app);
        copyProc.command = ["sh", "-c", 'cliphist decode "$0" | wl-copy', entry.id];
        copyProc.running = true;
    }

    Process {
        id: copyProc
        onExited: pasteTimer.start()
    }

    Timer {
        id: pasteTimer
        property bool viaTerminal: false
        interval: 150
        onTriggered: Quickshell.execDetached(viaTerminal
            ? ["wtype", "-M", "ctrl", "-M", "alt", "-k", "v", "-m", "alt", "-m", "ctrl"]
            : ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"])
    }
}
