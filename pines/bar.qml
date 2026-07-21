import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// pines: the instrument sill — a cold slate strip at the top of the cab's
// glass. Laid out like a quiet shelf, not a control panel: the lantern on the
// left opens the field desk, the survey traverse carries the workspaces
// (benchmark triangles on a hairline, the kerosene lamp condensing at the
// active station), thin serif time in the middle, and on the right the
// readings themselves — track, cpu/mem needles, signal, battery — with no
// nameplates. The instruments say what they are by shape, not by label.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color ember: pal.magenta
    readonly property color brass: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property string iconFont: "Symbols Nerd Font"
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot: the sill condenses — opacity up while the soft-focus settles
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // ── the benchmark triangle, drawn small ─────────────────────────────────
    component BenchMark: Canvas {
        id: bm
        property color tone: root.silverA(0.7)
        property real side: 9
        width: side + 2; height: side
        onToneChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = String(tone)
            ctx.lineWidth = 1.1
            ctx.beginPath()
            ctx.moveTo(width / 2, 0.8)
            ctx.lineTo(width - 0.8, height - 1)
            ctx.lineTo(0.8, height - 1)
            ctx.closePath()
            ctx.stroke()
            ctx.fillStyle = String(tone)
            ctx.fillRect(width / 2 - 0.8, height * 0.5, 1.6, 1.6)
        }
    }

    // a damped needle on a short rule — the shelf's level gauge
    component NeedleRule: Item {
        id: nr
        property real level: 0     // 0..1
        property color tone: root.silverA(0.9)
        width: 24; height: 9
        Rectangle { width: parent.width; height: 1; y: parent.height - 2; color: root.slateA(0.9) }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: (index + 1) * nr.width / 4
                y: nr.height - 4; width: 1; height: 3
                color: root.slateA(0.7)
            }
        }
        Rectangle {   // the needle
            x: Math.max(0, Math.min(nr.width - 1, nr.width * nr.level)) - 0.5
            y: 0; width: 1.5; height: nr.height - 1
            color: nr.tone
            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
        }
    }

    // ── the glass of the sill ───────────────────────────────────────────────
    // near-solid: the wallpaper's brightest sky sits right behind the bar, so
    // the sill has to be its own dark surface for anything on it to read
    Rectangle { anchors.fill: parent; color: root.glassA(0.88) }
    Rectangle {   // the sill's front edge, against the desktop
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.slateA(0.55)
    }
    Rectangle {   // a whisper of moonlight along the top
        width: parent.width; height: 1
        color: root.silverA(0.10)
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT

        // ── left: the lantern + the survey traverse ──────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // the lamp — opens the field desk
            Item {
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: 26; height: 26; radius: 13
                    color: deskMa.containsMouse ? root.lampA(0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Item {
                    anchors.centerIn: parent
                    width: 14; height: 16
                    readonly property color wire: deskMa.containsMouse ? root.lampA(1) : root.inkA(0.75)
                    Rectangle { x: 3; y: 0; width: 8; height: 1.5; color: parent.wire }
                    Rectangle { x: 1; y: 2.5; width: 1.5; height: 10.5; color: parent.wire }
                    Rectangle { x: 11.5; y: 2.5; width: 1.5; height: 10.5; color: parent.wire }
                    Rectangle { x: 3; y: 14; width: 8; height: 1.5; color: parent.wire }
                    Rectangle {
                        x: 5; y: 6; width: 4; height: 4; radius: 2
                        color: root.lamp
                        opacity: deskMa.containsMouse ? 1 : 0.85
                    }
                }
                MouseArea {
                    id: deskMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: root.slateA(0.8)
            }

            // the traverse: benchmark stations on a hairline, apps flying
            // above their marks, the lamp hanging at the active station
            Item {
                id: wsCluster
                readonly property int wsCount: 10
                readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
                readonly property int pageBase: activeWsId >= 1
                    ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
                    : 1
                readonly property real slotW: 32
                readonly property int activeSlot: activeWsId - pageBase
                width: wsCount * slotW
                height: root.height

                // the traverse hairline, running under every station
                Rectangle {
                    x: 0; y: Math.round(parent.height * 0.66)
                    width: parent.width; height: 1
                    color: root.slateA(0.8)
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

                        // the station mark on the traverse
                        BenchMark {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(slot.height * 0.66) - height + 1
                            tone: slot.isActive ? root.lampA(1)
                                : slot.isOccupied ? root.silverA(0.95)
                                : root.silverA(0.35)
                        }
                        // the sighting flag: whatever app rides this station
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 3
                            width: slot.isActive ? 18 : 16
                            height: width
                            visible: slot.isOccupied
                            source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                            opacity: slot.isActive ? 1 : 0.85
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                        }
                    }
                }

                // the lamp: hangs at the active station, re-condenses on switch
                Item {
                    id: lampAt
                    property int slotIdx: wsCluster.activeSlot
                    property real t: 1   // 1 condensed, 0 fog
                    x: slotIdx * wsCluster.slotW + wsCluster.slotW / 2 - width / 2
                    y: Math.round(parent.height * 0.66) + 3
                    width: 8; height: 8

                    Rectangle {   // halo
                        anchors.centerIn: parent
                        width: 20; height: 20; radius: 10
                        color: root.lampA(0.14 * lampAt.t)
                    }
                    Rectangle {   // flame
                        anchors.centerIn: parent
                        width: 6; height: 6; radius: 3
                        color: root.lamp
                        opacity: lampAt.t * lampAt.t
                        scale: 1 + 0.5 * (1 - lampAt.t)
                    }
                    // fog ghost while transitioning
                    Rectangle {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -5 * (1 - lampAt.t)
                        width: 6; height: 6; radius: 3
                        color: root.silverA(0.5)
                        opacity: 0.5 * (1 - lampAt.t) * Math.min(1, lampAt.t * 4 + 0.3)
                    }

                    SequentialAnimation {
                        id: relight
                        NumberAnimation { target: lampAt; property: "t"; to: 0; duration: 150; easing.type: Easing.InQuad }
                        ScriptAction { script: lampAt.slotIdx = wsCluster.activeSlot }
                        NumberAnimation { target: lampAt; property: "t"; to: 1; duration: 340; easing.type: Easing.OutCubic }
                    }
                    Connections {
                        target: wsCluster
                        function onActiveSlotChanged() { relight.restart() }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
                }
            }
        }

        // ── centre: thin serif time · date ───────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 11

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.inkA(1)
                font.family: root.serif
                font.pixelSize: 18
                font.letterSpacing: 1
            }
            BenchMark {
                anchors.verticalCenter: parent.verticalCenter
                side: 7
                tone: root.lampA(0.9)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd MMM d").toLowerCase()
                color: root.silverA(0.95)
                font.family: root.serif
                font.pixelSize: 13
                font.letterSpacing: 1
            }
        }

        // ── right: track · needles · signal · battery ────────────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // now playing: warm valve pip breathes while receiving, amber ink
            // trace runs under the title as the track progresses
            Item {
                visible: root.mediaActive
                width: mediaRow.width
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: mediaRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Rectangle {   // the valve pip — a warm tube, not an LED
                        id: valve
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: root.mediaPlaying ? root.lamp : root.slateA(0.9)
                        SequentialAnimation on opacity {
                            running: root.mediaPlaying && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                        onVisibleChanged: opacity = 1
                    }
                    Text {
                        id: mediaTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mediaLabel
                        textFormat: Text.PlainText
                        color: root.inkA(0.92)
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 200)
                        font.family: root.mono
                        font.pixelSize: 12
                    }
                }
                Rectangle {   // the ink trace
                    anchors.bottom: parent.bottom
                    x: mediaTitle.x
                    width: mediaTitle.width * root.mediaProgress
                    height: 1
                    color: root.lampA(0.7)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.mediaActive && root.player.canTogglePlaying) root.player.togglePlaying()
                    onWheel: (w) => {
                        if (!root.mediaActive) return
                        // shift+scroll nudges the live lyric offset, house standard
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

            // vitals: damped needles on short rules, values in plain mono.
            // hovering condenses the full instrument readout down
            Row {
                spacing: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pal.sysinfoOn !== false
                HoverHandler {
                    enabled: root.pal.sysinfoOn !== false
                    onHoveredChanged: sysFlag.setText(hovered ? "1" : "0")
                }
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    NeedleRule {
                        anchors.verticalCenter: parent.verticalCenter
                        level: root.cpuPct
                        tone: root.cpuPct > 0.9 ? root.ember : root.cpuPct > 0.75 ? root.brass : root.silverA(0.95)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cpu " + Math.round(root.cpuPct * 100) + "%"
                        color: root.inkA(0.88)
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                }
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    NeedleRule {
                        anchors.verticalCenter: parent.verticalCenter
                        level: root.memPct
                        tone: root.memPct > 0.9 ? root.ember : root.memPct > 0.75 ? root.brass : root.silverA(0.95)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mem " + Math.round(root.memPct * 100) + "%"
                        color: root.inkA(0.88)
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                }
            }

            // signal: one quiet glyph — silver while the set hears the
            // valley, ember when the wire is dead
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(root.connType === "ethernet" ? 0xF059F
                    : root.connType === "wifi" ? 0xF05A9 : 0xF092F)
                font.family: root.iconFont
                font.pixelSize: 14
                color: root.connType === "none" ? root.ember : root.silverA(0.9)
            }

            // battery: the unlabeled vial + a plain reading
            Row {
                visible: root.batPct >= 0
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 10
                    Rectangle {   // the vial
                        anchors.fill: parent
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.slateA(1)
                    }
                    Rectangle {   // the oil
                        x: 2; y: 2
                        width: Math.max(0, (parent.width - 4) * Math.max(0, root.batPct) / 100)
                        height: parent.height - 4
                        radius: 1
                        color: root.batCharging ? root.fogSilver
                             : root.batPct <= 15 ? root.ember
                             : root.batPct <= 30 ? root.brass
                             : root.lampA(0.95)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batPct + "%" + (root.batCharging ? " +" : "")
                    color: root.batPct <= 15 && !root.batCharging ? root.ember : root.inkA(0.88)
                    font.family: root.mono
                    font.pixelSize: 11
                }
            }
        }
    }

    // hover flag shared with sysinfo.qml — the vitals row writes here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

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
        return a ? t + " · " + a : t
    }
    property real mediaProgress: 0
    Timer {
        interval: 1000; repeat: true
        running: root.mediaPlaying && !root.occluded
        triggeredOnStart: true
        onTriggered: {
            const p = root.player
            root.mediaProgress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
    }

    // ── vitals + net + battery, one poll ─────────────────────────────────────
    property string connType: "none"
    property real cpuPct: 0
    property real memPct: 0
    property int batPct: -1
    property bool batCharging: false
    property var _prevCpu: null

    function parseStats(out) {
        let memT = 0, memA = 0
        for (const raw of out.trim().split("\n")) {
            const l = raw.trim()
            if (l.startsWith("net:")) root.connType = l.slice(4) || "none"
            else if (l.startsWith("cpu ")) {
                const f = l.split(/\s+/).slice(1).map(Number)
                const tot = f.reduce((a, b) => a + b, 0)
                const idle = f[3] + (f[4] || 0)
                if (root._prevCpu) {
                    const dt = tot - root._prevCpu.tot, di = idle - root._prevCpu.idle
                    if (dt > 0) root.cpuPct = Math.max(0, Math.min(1, (dt - di) / dt))
                }
                root._prevCpu = { tot: tot, idle: idle }
            }
            else if (l.startsWith("MemTotal")) memT = parseInt(l.split(/\s+/)[1])
            else if (l.startsWith("MemAvailable")) memA = parseInt(l.split(/\s+/)[1])
            else if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
        }
        if (memT > 0) root.memPct = Math.max(0, Math.min(1, 1 - memA / memT))
    }
    Process {
        id: statProc
        command: ["bash", "-c",
            'printf "net:%s\\n" "$(nmcli -t -f TYPE,STATE d 2>/dev/null | grep -m1 \':connected$\' | cut -d: -f1)"; ' +
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; " +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Timer {
        interval: 3000; repeat: true; running: !root.occluded; triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // ── workspace icon lookup ────────────────────────────────────────────────
    // keep the .desktop database observed so heuristicLookup() works
    readonly property int _keepAlive: DesktopEntries.applications.values.length
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
}
