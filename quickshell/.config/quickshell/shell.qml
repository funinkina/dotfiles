import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    IpcHandler {
        target: "dock"
        function toggle(): void {
            ShellState.dockVisible = !ShellState.dockVisible;
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { LockService.lock(); }
        function unlock(): void { LockService.unlock(); }
    }

    // One instance (owns the org.freedesktop.Notifications DBus name)
    NotificationPopup {}

    LockScreen {}

    Variants {
        model: Quickshell.screens

        Scope {
            id: s
            property var modelData

            Bar { modelData: s.modelData }
            Dock { modelData: s.modelData }
            Osd { modelData: s.modelData }
            DismissLayer { modelData: s.modelData }
            NetworkPanel { modelData: s.modelData }
            BatteryPanel { modelData: s.modelData }
            AudioPanel { modelData: s.modelData }
            DisplayPanel { modelData: s.modelData }
            MediaPanel { modelData: s.modelData }
            NotificationCenter { modelData: s.modelData }
        }
    }
}
