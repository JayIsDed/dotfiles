// SshLauncher.qml — `!` in the dank launcher lists every Host from
// ~/.ssh/config (wildcards skipped); picking one opens kitty ssh <host>.
import QtQuick
import Quickshell
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string trigger: "!"
    signal itemsChanged()

    property var hosts: []

    function loadHosts() {
        Proc.runCommand("sshLauncher.hosts",
            ["sh", "-c", "awk '/^Host /{for(i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.hosts = stdout.trim().split("\n").filter(h => h.length > 0)
                    root.itemsChanged()
                }
            }, 0, 4000)
    }
    Component.onCompleted: loadHosts()

    function getItems(query) {
        const q = (query || "").toLowerCase().trim()
        return root.hosts
            .filter(h => q === "" || h.toLowerCase().indexOf(q) !== -1)
            .map(h => ({
                name: h,
                icon: "material:terminal",
                comment: "ssh " + h + " · kitty",
                action: "ssh:" + h,
                categories: ["SSH"]
            }))
    }

    function executeItem(item) {
        Quickshell.execDetached(["kitty", "ssh", item.action.slice(4)])
    }
}
