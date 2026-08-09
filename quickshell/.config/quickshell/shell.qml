import Quickshell
import QtQuick

ShellRoot {
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
        }
    }
}
