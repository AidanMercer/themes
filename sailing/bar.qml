import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

// sailing: the deck railing — bottom bar for the "THROUGH SILENCE" wallpaper.
//
// The whole strip is the ferry's side railing seen from the deck: two thin
// parallel rails span the full width with stanchion posts dividing the module
// clusters (and faint intermediate posts along the empty runs). Workspaces
// are portholes set along the rail — the active one warm-lit in lifebuoy
// red-orange, occupied ones dim-lit lavender, empty ones dark glass. Left:
// the radio room (now-playing) with its progress riding the lower rail.
// Right: radio-mast signal arcs, the log clock, and the anchor (Super+M).
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color buoy:  pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color alarm: pal.magenta
    readonly property color lamp:  pal.amber
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function buoyA(a)  { return Qt.rgba(buoy.r, buoy.g, buoy.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // hover flag shared with sysinfo.qml (it watches this file and shows the
    // wheelhouse card while it reads "1") — same mirror-file idiom as AudioBus
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    // boot-in: the rails draw out from the left, portholes light in sequence
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    readonly property real railTopY: 8
    readonly property real railBotY: 36

    // deck shadow behind the railing
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.glassA(0.0) }
            GradientStop { position: 0.45; color: root.glassA(0.62) }
            GradientStop { position: 1.0; color: root.glassA(0.88) }
        }
    }

    // ── the rails ───────────────────────────────────────────────────────────
    Rectangle { y: root.railTopY; width: parent.width * root.bootT; height: 1; color: root.paleA(0.30) }
    Rectangle { y: root.railBotY; width: parent.width * root.bootT; height: 1; color: root.slateA(0.65) }

    // faint intermediate stanchions along the empty runs
    Repeater {
        model: Math.max(0, Math.floor(root.width / 190))
        Rectangle {
            required property int index
            x: 95 + index * 190
            y: root.railTopY - 1
            width: 1
            height: root.railBotY - root.railTopY + 3
            color: root.paleA(0.10)
            visible: root.bootT * root.width > x
        }
    }

    // a full stanchion post: brackets a module cluster
    component Stanchion: Item {
        width: 2
        height: root.railBotY - root.railTopY + 7
        Rectangle { anchors.fill: parent; color: root.paleA(0.38) }
        Rectangle { y: 0; width: 4; height: 2; x: -1; color: root.paleA(0.45) }   // cap
    }

    // ── center: workspace portholes along the rail ──────────────────────────
    Item {
        id: wsCluster
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: wsRow.width + 44
        height: parent.height
        opacity: root.bootT

        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1

        // keep toplevels fresh so occupancy tracks windows
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

        Stanchion { anchors.left: parent.left; y: root.railTopY - 3 }
        Stanchion { anchors.right: parent.right; y: root.railTopY - 3 }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 13

            Repeater {
                model: wsCluster.wsCount
                delegate: Item {
                    id: port
                    required property int index
                    readonly property int wsId: wsCluster.pageBase + index
                    readonly property bool isActive: wsCluster.activeWsId === wsId
                    readonly property bool isOccupied: Hyprland.toplevels.values
                        .some(t => (t.workspace?.id ?? -1) === wsId)

                    width: 18
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    // staggered light-up on boot
                    opacity: Math.max(0, Math.min(1, root.bootT * 2.2 - index * 0.12))

                    // warm halo behind the active porthole
                    Rectangle {
                        anchors.centerIn: ring
                        width: 26; height: 26; radius: 13
                        color: root.buoyA(0.16)
                        opacity: port.isActive ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 240 } }
                    }

                    // the porthole: glass + rim
                    Rectangle {
                        id: ring
                        anchors.centerIn: parent
                        width: 15; height: 15; radius: 7.5
                        color: port.isActive ? root.buoyA(0.30)
                             : port.isOccupied ? root.duskA(0.14) : root.glassA(0.55)
                        border.width: port.isActive ? 1.6 : 1
                        border.color: port.isActive ? root.buoy
                                    : port.isOccupied ? root.duskA(0.75) : root.slateA(0.55)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        // the lamp behind the glass
                        Rectangle {
                            anchors.centerIn: parent
                            width: 5; height: 5; radius: 2.5
                            color: port.isActive ? root.buoy
                                 : port.isOccupied ? root.duskA(0.6) : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${port.wsId}`)
                    }
                }
            }
        }
    }

    // ── left: the radio room (now-playing) ──────────────────────────────────
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
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        width: mediaRow.width
        height: parent.height
        opacity: root.bootT

        property real progress: 0
        function updateProgress() {
            const p = media.player
            media.progress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
        Timer {
            interval: 1000; repeat: true
            running: media.playing
            triggeredOnStart: true
            onTriggered: media.updateProgress()
        }

        Row {
            id: mediaRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            // a small porthole holding the play state
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 17; height: 17; radius: 8.5
                color: root.glassA(0.6)
                border.width: 1
                border.color: media.playing ? root.duskA(0.9) : root.slateA(0.7)
                Text {
                    anchors.centerIn: parent
                    text: media.playing ? String.fromCodePoint(0xF040A) : String.fromCodePoint(0xF03E4)
                    font.family: root.icon
                    font.pixelSize: 9
                    color: media.playing ? root.dusk : root.slateA(0.9)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 230)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + "  ·  " + a : t
                }
                textFormat: Text.PlainText
                color: root.paleA(0.85)
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 0.5
            }
        }

        // track progress rides the lower rail under the chip
        Rectangle {
            x: 0
            y: root.railBotY
            height: 1.6
            width: mediaRow.width * media.progress
            color: root.buoyA(0.9)
            Behavior on width { NumberAnimation { duration: 900 } }
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

    // ── right: instruments — signal arcs · log clock · the anchor ───────────
    // connection poll (nmcli, every 10s)
    property bool online: false
    property string connName: ""
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connName = ""; return }
                root.online = true
                root.connName = line.slice(0, line.lastIndexOf(":"))
            }
        }
    }

    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20
        opacity: root.bootT

        // radio mast: three arcs over a dot, lit while the ship has shore signal
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: sigRow.width
            height: 20

            Row {
                id: sigRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Canvas {
                    id: mast
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 15
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2, cy = height - 2
                        ctx.fillStyle = root.online ? root.dusk : root.slateA(0.9)
                        ctx.beginPath(); ctx.arc(cx, cy, 1.8, 0, Math.PI * 2); ctx.fill()
                        for (let i = 1; i <= 3; i++) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, 2.5 + i * 3.4, -Math.PI * 0.78, -Math.PI * 0.22)
                            ctx.strokeStyle = root.online
                                ? root.duskA(1.05 - i * 0.22)
                                : root.slateA(0.35)
                            ctx.lineWidth = 1.4
                            ctx.stroke()
                        }
                    }
                    Connections {
                        target: root
                        function onOnlineChanged() { mast.requestPaint() }
                    }
                    Connections {
                        target: root.pal
                        function onCyanChanged() { mast.requestPaint() }
                        function onDimChanged() { mast.requestPaint() }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 130)
                    elide: Text.ElideRight
                    text: root.online ? root.connName.toUpperCase() : "NO SIGNAL"
                    textFormat: Text.PlainText
                    color: root.online ? root.duskA(0.75) : root.alarm
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }
            }
        }

        Stanchion { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1 }

        // the log clock
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LOG"
                color: root.duskA(0.65)
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 3
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.pale
                font.family: root.mono
                font.pixelSize: 13
                font.letterSpacing: 2
            }
        }

        Stanchion { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1 }

        // wheelhouse dial — hover to consult the instruments (sysinfo card);
        // gone while the readout is toggled off in settings
        Item {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 28
            Rectangle {
                anchors.centerIn: parent
                width: 16; height: 16; radius: 8
                color: root.glassA(0.6)
                border.width: 1
                border.color: gaugeMa.containsMouse ? root.lamp : root.slateA(0.8)
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Rectangle {
                    x: parent.width / 2 - 5.5; y: parent.height / 2 - 0.6
                    width: 5.5; height: 1.2; radius: 0.6
                    transformOrigin: Item.Right
                    rotation: gaugeMa.containsMouse ? 210 : 320
                    color: gaugeMa.containsMouse ? root.buoy : root.paleA(0.8)
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 1.5
                    color: gaugeMa.containsMouse ? root.lamp : root.slateA(0.9)
                }
            }
            MouseArea {
                id: gaugeMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        Stanchion { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1 }

        // the anchor — drops the control popup
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 28
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0031)   // nf-md-anchor
                font.family: root.icon
                font.pixelSize: 15
                color: anchorMa.containsMouse ? root.buoy : root.paleA(0.75)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                id: anchorMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
