pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Claude Code usage limits, fetched via scripts/claude-usage.py
// (Anthropic OAuth endpoints, using the Claude Code CLI's credentials).
Singleton {
    id: root

    property var data: null
    property double updatedAt: 0
    readonly property bool ok: data?.ok ?? false
    readonly property real weekPct: data?.seven_day?.pct ?? 0
    readonly property real sessionPct: data?.five_hour?.pct ?? 0

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var now: clock.date

    function refresh() { proc.running = true; }

    // "2d 4h" / "4h 32m" / "32m"; short=true keeps only the leading unit
    function eta(iso, short) {
        if (!iso)
            return "";
        const m = Math.round((new Date(iso) - now) / 60000);
        if (m <= 0)
            return "now";
        if (m < 60)
            return m + "m";
        const h = Math.floor(m / 60);
        if (h < 24)
            return short ? h + "h" : h + "h " + (m % 60) + "m";
        const d = Math.floor(h / 24);
        return short ? d + "d" : d + "d " + (h % 24) + "h";
    }

    function resetTime(iso) {
        if (!iso)
            return "";
        const d = new Date(iso);
        return Qt.formatDateTime(d, d - now > 86400000 ? "ddd HH:mm" : "HH:mm");
    }

    Process {
        id: proc
        command: ["python3",
            "/home/funinkina/.config/quickshell/scripts/claude-usage.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try { d = JSON.parse(text); } catch (e) { return; }
                // Never replace good data with an error state
                if (d.ok || root.data === null)
                    root.data = d;
                if (d.ok)
                    root.updatedAt = Date.now();
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
