//@ pragma UseQApplication
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

    IpcHandler {
        target: "dnd"
        function toggle(): void { NotifService.toggleDnd(); }
        function on(): void { NotifService.setDnd(true); }
        function off(): void { NotifService.setDnd(false); }
    }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { CaffeineService.toggle(); }
        function on(): void { CaffeineService.setActive(true); }
        function off(): void { CaffeineService.setActive(false); }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { ShellState.togglePanel("power"); }
    }

    IpcHandler {
        target: "panel"
        function toggle(name: string, screen: string): void {
            ShellState.togglePanel(name, screen);
        }
    }

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
            CalendarPanel { modelData: s.modelData }
            PowerMenu { modelData: s.modelData }
            BluetoothPanel { modelData: s.modelData }
            MediaPanel { modelData: s.modelData }
            WindowPanel { modelData: s.modelData }
            ClaudePanel { modelData: s.modelData }
            NotificationCenter { modelData: s.modelData }
        }
    }
}
