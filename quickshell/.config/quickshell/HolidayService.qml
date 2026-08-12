pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Indian holidays and observances, read from the cache that
// scripts/holidays.py writes (see that file for the source and refresh rules).
Singleton {
    id: root

    // "YYYY-MM-DD" -> [{ n: name, p: 1 gazetted | 0 observance }]
    property var days: ({})

    // Local calendar date, never toISOString(): that converts to UTC and
    // lands on the wrong day for every timezone with a non-zero offset.
    function key(d) {
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
    }

    function forKey(k) { return days[k] ?? []; }
    function forDate(d) { return forKey(key(d)); }

    FileView {
        id: cache
        path: "/home/funinkina/.cache/quickshell/holidays.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.days = JSON.parse(cache.text())?.days ?? ({});
            } catch (e) {
                root.days = ({});
            }
        }
    }

    // Runs once at shell startup, nothing after. The script only touches the
    // network if the cache has aged past its TTL, so this is normally a
    // read-nothing no-op; the feed already covers through 2031.
    Process {
        command: ["python3",
            "/home/funinkina/.config/quickshell/scripts/holidays.py"]
        running: true
        // The file may not exist on a first run, so watchChanges has nothing
        // to watch yet — reload explicitly once the script has written it
        onExited: cache.reload()
    }
}
