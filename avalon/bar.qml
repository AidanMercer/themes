import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// avalon: minimal top strip on moss glass. Workspaces as buds on the left,
// serif time in the middle, quiet media/net/battery cluster on the right,
// one gold hairline along the bottom edge.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal

    readonly property color ivory: pal.text
    readonly property color blue:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color dim:   pal.dim
    readonly property color moss:  pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property string sans:  "Noto Sans"
    readonly property string iconFont: "Symbols Nerd Font"

    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function blueA(a)  { return Qt.rgba(blue.r, blue.g, blue.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.72) }
            GradientStop { position: 1.0; color: Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.52) }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: root.goldA(0.30)
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT
        transform: Translate { y: -6 * (1 - root.bootT) }

        // ── left: arch + workspaces ──────────────────────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Item {
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: archMa.containsMouse ? root.goldA(0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF303)   // nf-linux-archlinux
                    font.family: root.iconFont
                    font.pixelSize: 15
                    color: archMa.containsMouse ? root.ivory : root.gold
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: archMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: root.ivoryA(0.12)
            }

            Item {
                width: wsRow.width
                height: parent.height

                Row {
                    id: wsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    readonly property int wsCount: 10
                    readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
                    readonly property int pageBase: activeWsId >= 1
                        ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
                        : 1
                    // keep the .desktop database observed so heuristicLookup() works
                    readonly property int _keepAlive: DesktopEntries.applications.values.length

                    Repeater {
                        model: wsRow.wsCount
                        delegate: Item {
                            id: slot
                            required property int index
                            readonly property int wsId: wsRow.pageBase + index
                            readonly property bool isActive: wsRow.activeWsId === wsId
                            readonly property var windowsHere: Hyprland.toplevels.values
                                .filter(t => (t.workspace?.id ?? -1) === wsId)
                            readonly property bool isOccupied: windowsHere.length > 0

                            width: 28
                            height: 30

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26; height: 26; radius: 9
                                color: root.blueA(slot.isActive ? 0.20 : 0)
                                border.width: slot.isActive ? 1 : 0
                                border.color: root.goldA(0.40)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            // empty: a bud — ivory dot, gold while active
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !slot.isOccupied
                                width: slot.isActive ? 6 : 4
                                height: width
                                radius: width / 2
                                color: slot.isActive ? root.gold : root.ivoryA(0.30)
                                Behavior on width { NumberAnimation { duration: 180 } }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                visible: slot.isOccupied
                                width: 15; height: 15
                                source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                                opacity: slot.isActive ? 1.0 : 0.55
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
                }
            }
        }

        // ── centre: serif time · date ────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.ivory
                font.family: root.serif
                font.pixelSize: 17
                font.letterSpacing: 2
            }
            Rectangle {
                width: 4; height: 4
                rotation: 45
                color: root.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd MMM dd").toUpperCase()
                color: root.ivoryA(0.55)
                font.family: root.sans
                font.pixelSize: 10
                font.letterSpacing: 3
            }
        }

        // ── right: media · net · battery ─────────────────────────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // now playing: state dot + title with a gold progress hairline
            Item {
                visible: root.mediaActive
                width: mediaRow.width
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: mediaRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.mediaPlaying ? root.gold : root.ivoryA(0.35)
                        SequentialAnimation on opacity {
                            running: root.mediaPlaying
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        id: mediaTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mediaLabel
                        color: root.ivoryA(0.72)
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 170)
                        font.family: root.sans
                        font.pixelSize: 10
                        font.letterSpacing: 0.4
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    x: mediaTitle.x
                    width: mediaTitle.width * root.mediaProgress
                    height: 1
                    color: root.goldA(0.55)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.mediaActive && root.player.canTogglePlaying) root.player.togglePlaying()
                    onWheel: (w) => {
                        if (!root.mediaActive) return
                        // shift+scroll nudges the live lyric offset, same as moon/shiro
                        if (w.modifiers & Qt.ShiftModifier) {
                            Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                                w.angleDelta.y > 0 ? "earlier" : "later"])
                            return
                        }
                        if (w.angleDelta.y > 0 && root.player.canGoNext) root.player.next()
                        else if (w.angleDelta.y < 0 && root.player.canGoPrevious) root.player.previous()
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(root.connType === "ethernet" ? 0xF059F
                    : root.connType === "wifi" ? 0xF05A9 : 0xF092F)
                font.family: root.iconFont
                font.pixelSize: 13
                color: root.connType === "none" ? root.rose : root.blueA(0.85)
            }

            Row {
                visible: root.batPct >= 0
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 4; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.batPct < 20 && !root.batCharging ? root.rose
                         : root.batCharging ? root.gold : root.ivoryA(0.45)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batPct + "%" + (root.batCharging ? " ↑" : "")
                    color: root.ivoryA(0.60)
                    font.family: root.sans
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── mpris ────────────────────────────────────────────────────────────────
    readonly property var player: {
        const ps = Mpris.players.values
        if (ps.length === 0) return null
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
    }
    readonly property bool mediaActive: player !== null
    readonly property bool mediaPlaying: mediaActive && player.playbackState === MprisPlaybackState.Playing
    readonly property string mediaLabel: {
        if (!mediaActive) return ""
        const t = player.trackTitle || "—"
        const a = player.trackArtist
        return a ? t + "  ·  " + a : t
    }
    property real mediaProgress: 0
    Timer {
        interval: 1000; repeat: true
        running: root.mediaPlaying
        triggeredOnStart: true
        onTriggered: {
            const p = root.player
            root.mediaProgress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
    }

    // ── net + battery ────────────────────────────────────────────────────────
    property string connType: "none"
    property int batPct: -1
    property bool batCharging: false

    function parseStats(out) {
        for (const raw of out.trim().split("\n")) {
            const l = raw.trim()
            if (l.startsWith("net:")) root.connType = l.slice(4) || "none"
            else if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
        }
    }
    Process {
        id: statProc
        command: ["bash", "-c",
            'printf "net:%s\\n" "$(nmcli -t -f TYPE,STATE d 2>/dev/null | grep -m1 \':connected$\' | cut -d: -f1)"; ' +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Timer {
        interval: 5000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // ── workspace icon lookup (same tricks as the default bar) ───────────────
    Component.onCompleted: Hyprland.refreshToplevels()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "activewindowv2":
                Hyprland.refreshToplevels()
            }
        }
    }
    function iconForClass(cls) {
        if (!cls) return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        const name = (entry && entry.icon) ? entry.icon : cls.toLowerCase()
        return Quickshell.iconPath(name, "application-x-executable")
    }
    function iconForWindows(wins) {
        let best = null, bestFh = Infinity
        for (const w of wins) {
            const cls = w.lastIpcObject?.class ?? ""
            if (!cls) continue
            const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
            if (fh < bestFh) { best = w; bestFh = fh }
        }
        return best ? iconForClass(best.lastIpcObject.class)
                    : Quickshell.iconPath("application-x-executable")
    }
}
