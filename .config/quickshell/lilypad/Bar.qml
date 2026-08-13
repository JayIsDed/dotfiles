// Bar.qml — floating glass island (2025 custom-waybar geometry: 40 high,
// 6 top / 10 side margins). The window is full-width and transparent; the
// island is drawn inset, so no unverified margin API is involved.
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

    readonly property int islandH: 40
    readonly property int mTop: 6
    readonly property int mSide: 10

    anchors { left: true; right: true; top: true }
    implicitHeight: islandH + mTop + 4
    exclusiveZone: islandH + mTop + 4
    color: "transparent"
    WlrLayershell.namespace: "lilypad"

    Rectangle {
        id: island
        anchors.top: parent.top
        anchors.topMargin: bar.mTop
        anchors.left: parent.left
        anchors.leftMargin: bar.mSide
        anchors.right: parent.right
        anchors.rightMargin: bar.mSide
        height: bar.islandH
        radius: 14
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.islandAlpha)
        border.color: Theme.border
        border.width: 1

        // ── left: workspaces · window title
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Workspaces { Layout.alignment: Qt.AlignVCenter }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: bar.width * 0.25
                text: Hyprland.activeToplevel?.title ?? ""
                color: Theme.text2
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
        }

        // ── center: media · clock · weather (the 2025 arrangement)
        RowLayout {
            anchors.centerIn: parent
            spacing: 16

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

        // ── right: the module fleet
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 13

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
            MetricsCluster { Layout.alignment: Qt.AlignVCenter }
            Battery { Layout.alignment: Qt.AlignVCenter }
            ScriptModule {
                id: notif
                Layout.alignment: Qt.AlignVCenter
                script: "notifications.sh"; interval: 2000
                leftCmd: ["swaync-client", "-t", "-sw"]
                rightCmd: ["swaync-client", "-C"]
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 26
                radius: 8
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
