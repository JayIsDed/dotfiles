// Bar.qml — floating tile row, pass 4 geometry: three fixed anchors
// (workspaces west, clock dead-center, power east) and two self-centering
// bundles that float at the midpoint of their spans. Bundles recenter as
// their content grows (task switcher, dvm tile), so the bar never reads
// lopsided. Same one window + blur layer throughout.
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
    // hypr gaps_out (8) is measured from the exclusive-zone edge; claiming
    // only barHeight makes window-top land at tile-bottom + islandMargin,
    // matching the tile-to-screen-top gap
    exclusiveZone: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "lilypad"

    // one floating tile — near-black glass, blur behind. autoHide collapses
    // the pill when every module inside is empty/hidden (no sliver pills).
    component Tile: Rectangle {
        property bool autoHide: false
        default property alias content: inner.data
        implicitWidth: inner.implicitWidth + 28
        implicitHeight: Theme.barHeight
        radius: Theme.islandRadius
        color: Theme.alpha(Theme.tileBase, Theme.islandAlpha)
        border.color: Theme.border
        border.width: 1
        visible: !autoHide || inner.implicitWidth > 8
        RowLayout {
            id: inner
            anchors.centerIn: parent
            spacing: 12
        }
    }

    // ── fixed west: workspaces
    Tile {
        id: wsTile
        anchors.left: parent.left
        anchors.leftMargin: Theme.barSideMargin
        anchors.verticalCenter: parent.verticalCenter
        Workspaces { Layout.alignment: Qt.AlignVCenter }
    }

    // ── fixed center: media · clock · weather
    Tile {
        id: clockTile
        anchors.centerIn: parent
        ScriptModule {
            Layout.alignment: Qt.AlignVCenter
            script: "media-player.sh"; interval: 3000
            tone: Theme.text3
            maxWidth: 320
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

    // ── fixed east: audio · network · brightness · power · battery · panel
    Tile {
        id: powerTile
        anchors.right: parent.right
        anchors.rightMargin: Theme.barSideMargin
        anchors.verticalCenter: parent.verticalCenter
        Volume  { Layout.alignment: Qt.AlignVCenter }
        Network { Layout.alignment: Qt.AlignVCenter }
        BrightnessChip { Layout.alignment: Qt.AlignVCenter }
        PowerDraw { Layout.alignment: Qt.AlignVCenter }
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

    // ── left bundle: sys card · tasks · dvm, centered in the ws↔clock span
    RowLayout {
        id: leftBundle
        anchors.verticalCenter: parent.verticalCenter
        x: {
            const spanStart = wsTile.x + wsTile.width + Theme.pad
            // clamp: an overgrown bundle hugs the workspaces side rather
            // than sliding under the clock (responsive collapse = later)
            return Math.max(spanStart, spanStart + (clockTile.x - spanStart - width) / 2)
        }
        spacing: Theme.pad

        Tile { SysCard { Layout.alignment: Qt.AlignVCenter } }
        Tile {
            visible: tasks.any
            TaskSwitcher { id: tasks; Layout.alignment: Qt.AlignVCenter }
        }
        Tile {
            visible: dockerTile.alive
            DockerTile { id: dockerTile; Layout.alignment: Qt.AlignVCenter }
        }
    }

    // ── right bundle: chips · metric tiles, centered in the clock↔power span
    RowLayout {
        id: rightBundle
        anchors.verticalCenter: parent.verticalCenter
        x: {
            const spanStart = clockTile.x + clockTile.width + Theme.pad
            return Math.max(spanStart, spanStart + (powerTile.x - spanStart - width) / 2)
        }
        spacing: Theme.pad

        Tile {
            autoHide: true
            ScriptModule {
                Layout.alignment: Qt.AlignVCenter
                script: "updates.sh"; interval: 3600000
                leftCmd: ["kitty", "-e", "sudo", "pacman", "-Syu"]
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
            ScriptModule {
                id: notif
                Layout.alignment: Qt.AlignVCenter
                script: "notifications.sh"; interval: 2000
                leftCmd: ["swaync-client", "-t", "-sw"]
                rightCmd: ["swaync-client", "-C"]
            }
        }

        MetricsCluster { Layout.alignment: Qt.AlignVCenter }
    }

    LazyLoader {
        id: panelLoader
        ControlPanel {
            barWindow: bar
            onDismissed: panelLoader.active = false
        }
    }
}
