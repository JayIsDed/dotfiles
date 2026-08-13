// Bar.qml — floating tile row (design pass 3: the single island dissolved
// into per-group tiles; same one window + blur layer, so the split costs
// nothing — hypr blurs painted pixels only, gaps stay wallpaper).
// Alignment: anchored sections (left / center / right), layouts only inside.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true }
    implicitHeight: Theme.barHeight + Theme.islandMargin * 2
    exclusiveZone: Theme.barHeight + Theme.islandMargin * 2
    color: "transparent"
    WlrLayershell.namespace: "lilypad"

    // one floating tile — near-black glass, blur behind
    component Tile: Rectangle {
        default property alias content: inner.data
        implicitWidth: inner.implicitWidth + 28
        implicitHeight: Theme.barHeight
        radius: Theme.islandRadius
        color: Theme.alpha(Theme.tileBase, Theme.islandAlpha)
        border.color: Theme.border
        border.width: 1
        RowLayout {
            id: inner
            anchors.centerIn: parent
            spacing: 12
        }
    }

    // ── left: workspaces tile · window-title tile (hides when empty)
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Theme.islandMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pad

        Tile { Workspaces { Layout.alignment: Qt.AlignVCenter } }
        Tile { SysCard { Layout.alignment: Qt.AlignVCenter } }
        Tile {
            visible: tasks.any
            TaskSwitcher { id: tasks; Layout.alignment: Qt.AlignVCenter }
        }
    }

    // ── center: media · clock · weather tile
    Tile {
        anchors.centerIn: parent
        ScriptModule {
            Layout.alignment: Qt.AlignVCenter
            script: "media-player.sh"; interval: 3000
            tone: Theme.text3
            leftCmd: ["playerctl", "play-pause"]
            rightCmd: ["playerctl", "next"]
        }
        Clock { Layout.alignment: Qt.AlignVCenter }
        ScriptModule {
            Layout.alignment: Qt.AlignVCenter
            script: "weather.sh"; interval: 900000
            tone: Theme.text3
        }
    }

    // ── right: chips tile · metric tiles (cluster draws its own) · power tile
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Theme.islandMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.pad

        Tile {
            ScriptModule {
                Layout.alignment: Qt.AlignVCenter
                script: "updates.sh"; interval: 3600000
                leftCmd: ["kitty", "-e", "sudo", "pacman", "-Syu"]
            }
            ScriptModule {
                Layout.alignment: Qt.AlignVCenter
                script: "docker-status.sh"; interval: 30000
                leftCmd: ["kitty", "ssh", "docker-services"]
            }
            Tray { Layout.alignment: Qt.AlignVCenter }
            ScriptModule {
                id: nightlight
                Layout.alignment: Qt.AlignVCenter
                script: "nightlight.sh"; interval: 5000
                leftCmd: ["bash", Quickshell.shellDir + "/scripts/nightlight-toggle.sh"]
            }
            ScriptModule {
                id: mic
                Layout.alignment: Qt.AlignVCenter
                script: "mic.sh"; interval: 2000
                leftCmd: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
            }
            ScriptModule {
                Layout.alignment: Qt.AlignVCenter
                script: "bluetooth.sh"; interval: 5000
                leftCmd: ["blueman-manager"]
            }
            Volume  { Layout.alignment: Qt.AlignVCenter }
            Network { Layout.alignment: Qt.AlignVCenter }
            ScriptModule {
                id: notif
                Layout.alignment: Qt.AlignVCenter
                script: "notifications.sh"; interval: 2000
                leftCmd: ["swaync-client", "-t", "-sw"]
                rightCmd: ["swaync-client", "-C"]
            }
        }

        MetricsCluster { Layout.alignment: Qt.AlignVCenter }

        Tile {
            BrightnessChip { Layout.alignment: Qt.AlignVCenter }
            Battery { Layout.alignment: Qt.AlignVCenter }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 26
                radius: Theme.chipRadius
                color: panelLoader.active ? Theme.elevated : "transparent"
                border.color: panelLoader.active ? Theme.borderStrong : Theme.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󱍢"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 15
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: panelLoader.active = !panelLoader.active
                }
            }
        }
    }

    LazyLoader {
        id: panelLoader
        ControlPanel {
            barWindow: bar
            onDismissed: panelLoader.active = false
        }
    }
}
