import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// encore: the bar is the LIGHT DESK at the lip of the stage — the strip of
// console the diva can see from her side. Flat stage-black modules with a
// teal edge-strip along their feet, capsule shapes only (this rig has no
// chamfers — moon owns those).
//   left   — media: a beat pip ticking the internal count, the track title,
//            and the song's progress as a 14-lamp LED ladder that fills in
//            whole lamps (law 1 — no sliding needles).
//   center — the CHANNEL STRIP: ten workspaces as ten faders. The active
//            channel's fader is pushed up and lit; occupied channels sit at
//            half with their app riding the module; empty channels rest at
//            the bottom, dark. Faders SNAP between detents — a light cue,
//            not a glide (law 2).
//   right  — sys lamp (hover = the rack panel drops), net signal ladder,
//            battery lamps, the time, and the ✳ button for the popup.
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color teal: pal.neon
    readonly property color lacquer: pal.cyan
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    readonly property color rest: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function tealA(a)  { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function crowdA(a) { return Qt.rgba(crowd.r, crowd.g, crowd.b, a) }
    function restA(a)  { return Qt.rgba(rest.r, rest.g, rest.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the desk is lit — a fast cut in, then the modules iris to size
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 420; easing.type: Easing.OutBack }
    readonly property real bootOp: bootT > 0.15 ? 1 : 0     // the cut
    readonly property real bootScale: 0.92 + 0.08 * Math.min(1, bootT)

    // ── a desk module: stage-black capsule with a teal edge-strip foot ──────
    component DeskPanel: Item {
        id: dp
        property real strip: 0.5       // edge-strip opacity share
        property color stripCol: root.teal
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.glassA(0.85)
            border.width: 1
            border.color: root.restA(0.45)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.height * 0.8
            height: 2
            radius: 1
            color: Qt.rgba(dp.stripCol.r, dp.stripCol.g, dp.stripCol.b, dp.strip)
        }
    }

    // the desk face itself: near-black, one hairline at the foot
    Rectangle {
        anchors.fill: parent
        color: root.glassA(0.6)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.restA(0.5)
    }

    // ── center: the channel strip ───────────────────────────────────────────
    Item {
        id: wsCluster
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 32
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootOp
        scale: root.bootScale

        function iconForWindows(wins) {
            let best = null, bestFh = Infinity
            for (const w of wins) {
                const cls = w.lastIpcObject?.class ?? ""
                if (!cls) continue
                const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
                if (fh < bestFh) { best = w; bestFh = fh }
            }
            if (!best) return Quickshell.iconPath("application-x-executable")
            const entry = DesktopEntries.heuristicLookup(best.lastIpcObject.class)
            const name = (entry && entry.icon) ? entry.icon : best.lastIpcObject.class.toLowerCase()
            return Quickshell.iconPath(name, "application-x-executable")
        }

        Repeater {
            model: wsCluster.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: wsCluster.pageBase + index
                readonly property bool isActive: wsCluster.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * wsCluster.slotW
                width: wsCluster.slotW
                height: parent.height

                // the fader track
                Rectangle {
                    id: track
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    width: 2
                    height: 16
                    radius: 1
                    color: root.restA(slot.isActive ? 0.9 : 0.5)
                }
                // the fader cap — three detents: up (live), half (patched), down
                Rectangle {
                    readonly property int detent: slot.isActive ? 0 : slot.isOccupied ? 1 : 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: track.y + detent * 6
                    width: 11
                    height: 4
                    radius: 2
                    color: slot.isActive ? root.teal
                         : slot.isOccupied ? root.tealA(0.55)
                         : root.restA(0.6)
                    // the live channel's cap carries the follow-spot line
                    Rectangle {
                        visible: slot.isActive
                        anchors.centerIn: parent
                        width: 5; height: 2; radius: 1
                        color: root.spot
                    }
                    // no Behavior — faders land on detents, they don't glide
                }
                // the app riding this channel
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 3
                    width: slot.isActive ? 15 : 13
                    height: width
                    visible: slot.isOccupied
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: slot.isActive ? 1 : 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }
    }

    // keep workspace occupancy fresh — toplevels are empty until refreshed
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
    Component.onCompleted: Hyprland.refreshToplevels()

    // ── left: the media module ──────────────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        x: 12
        y: Math.round((parent.height - height) / 2)
        width: mediaRow.width + 26
        height: 28
        opacity: root.bootOp
        scale: root.bootScale

        DeskPanel { anchors.fill: parent; strip: media.playing ? 0.6 : 0.2 }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 8

            // the beat pip: the desk's metronome, hard on/off at the count
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                property bool tick: true
                color: media.playing ? (tick ? root.teal : root.restA(0.8)) : root.restA(0.8)
                Timer {
                    interval: 500; repeat: true
                    running: media.playing && !root.occluded
                    onTriggered: pip.tick = !pip.tick
                }
                onVisibleChanged: if (!visible) tick = true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + " · " + a : t
                }
                textFormat: Text.PlainText
                color: root.inkA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // song progress: a 14-lamp ladder that fills lamp by lamp
        property real progress: 0
        Timer {
            interval: 1000; repeat: true
            running: media.playing && !root.occluded
            triggeredOnStart: true
            onTriggered: {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottomMargin: 4
            spacing: 3
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 5; height: 2; radius: 1
                    color: index < Math.round(media.progress * 14) ? root.tealA(0.9) : root.restA(0.5)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
            onWheel: (w) => {
                if (!media.active) return
                if (w.modifiers & Qt.ShiftModifier) {
                    Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                        w.angleDelta.y > 0 ? "earlier" : "later"])
                    return
                }
                if (w.angleDelta.y > 0 && media.player.canGoNext) media.player.next()
                else if (w.angleDelta.y < 0 && media.player.canGoPrevious) media.player.previous()
            }
        }
    }

    // ── right: desk tell-tales ──────────────────────────────────────────────
    property bool online: false
    property string connType: ""
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    Timer {
        interval: 10000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; batProc.running = true }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connType = ""; return }
                const t = line.slice(line.lastIndexOf(":") + 1)
                root.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                root.online = true
            }
        }
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cap = parseInt(lines[0])
                if (lines[0] === "" || isNaN(cap)) { root.hasBattery = false; return }
                root.hasBattery = true
                root.batteryPercent = cap
                root.batteryCharging = (lines[1] || "").trim() === "Charging"
            }
        }
    }

    // hover flag shared with sysinfo.qml — the DESK lamp writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: parent.height
        opacity: root.bootOp
        scale: root.bootScale

        // sys — hover to drop the rack panel.
        // gone while the readout is toggled off in settings.
        DeskPanel {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 24
            strip: deskMa.containsMouse ? 0.9 : 0.35
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "sys"
                color: deskMa.containsMouse ? root.teal : root.inkA(0.7)
                font.family: root.mono
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
            MouseArea {
                id: deskMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // net signal: four lamp steps, whole lamps only
        DeskPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 24
            strip: root.online ? 0.35 : 0   // offline: the strip goes dark, the crowd dot takes over
            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property int lit: root.online ? (root.connType === "eth" ? 4 : 3) : 0
                        width: 3
                        height: 4 + index * 3
                        radius: 1.5
                        anchors.bottom: parent.bottom
                        color: index < lit ? root.teal : root.restA(0.7)
                    }
                }
            }
            // signal lost: the crowd's colour takes the lamp
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                width: 4; height: 4; radius: 2
                color: root.crowd
                visible: !root.online
            }
        }

        // battery: five charge lamps in a capsule (laptops only)
        DeskPanel {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 24
            strip: root.batteryCharging ? 0.8 : 0.3
            stripCol: root.batteryCharging ? root.lacquer : root.teal
            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                spacing: 2
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: 4; height: 8; radius: 2
                        color: (root.batteryPercent >= 0 && index < Math.ceil(root.batteryPercent / 20))
                             ? (root.batteryCharging ? root.lacquer
                                : root.batteryPercent <= 15 ? root.crowd
                                : root.batteryPercent <= 30 ? root.spot
                                : root.teal)
                             : root.restA(0.5)
                    }
                }
            }
        }

        // the time — the desk's own cue clock, small
        DeskPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: timeText.implicitWidth + 22
            height: 24
            Text {
                id: timeText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.ink
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }

        // ✳ — the menu button (control popup), wearing the rig's spark glyph
        DeskPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 24
            strip: cueMa.containsMouse ? 0.9 : 0.35
            stripCol: cueMa.containsMouse ? root.spot : root.teal
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "✳"
                color: cueMa.containsMouse ? root.spot : root.inkA(0.7)
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.Bold
            }
            MouseArea {
                id: cueMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
