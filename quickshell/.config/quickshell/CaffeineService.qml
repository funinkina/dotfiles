pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Caffeine: stops the machine sleeping, nothing else. The logind inhibitor is
// held by a child process rather than tied to session idle state, so it keeps
// working across a lock. Idle lock and monitor blanking are untouched — they
// still fire on swayidle's normal timeouts, they just can't lead to suspend.
Singleton {
    id: root

    // Survives a config reload; a fresh shell process starts off.
    PersistentProperties {
        id: store
        reloadableId: "caffeineService"
        property bool active: false
    }

    readonly property alias active: store.active

    function toggle() { store.active = !store.active; }
    function setActive(on) { store.active = on; }

    Process {
        id: inhibitor
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch",
            "--who=Caffeine", "--why=Caffeine is on", "--mode=block",
            "sleep", "infinity"]
        running: root.active
        // The lock lives and dies with this process. If it ever exits on its
        // own the machine can sleep again, so drop the state rather than let
        // the bar claim an inhibitor that isn't there.
        onExited: root.setActive(false)
    }
}
