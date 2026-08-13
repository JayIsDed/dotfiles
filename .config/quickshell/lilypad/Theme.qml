// Theme.qml — pond tokens, QML edition. Values mirror the-pond/shared/tokens.css
// (pond set). Matugen JSON hookup can replace the statics later without
// touching consumers.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // surfaces — near-black, blue-green cast
    readonly property color bg: "#05090a"
    readonly property color surface: "#0b1214"
    readonly property color elevated: "#101b1d"

    // text — three tiers, always three
    readonly property color text: "#e6f0ee"
    readonly property color text2: Qt.rgba(230/255, 240/255, 238/255, 0.62)
    readonly property color text3: Qt.rgba(230/255, 240/255, 238/255, 0.33)

    // status + accent
    readonly property color green: "#4ade80"
    readonly property color amber: "#fbbf24"
    readonly property color red: "#f87171"
    readonly property color blue: "#5cc8e8"
    readonly property color purple: "#a78bfa"
    readonly property color accent: green

    // borders
    readonly property color border: Qt.rgba(186/255, 232/255, 222/255, 0.085)
    readonly property color borderStrong: Qt.rgba(186/255, 232/255, 222/255, 0.17)

    readonly property int barHeight: 36
    readonly property int radius: 10
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
}
