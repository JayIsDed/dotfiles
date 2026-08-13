// lilypad — the desktop shell. One bar per monitor; panel rides the bar.
import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
}
