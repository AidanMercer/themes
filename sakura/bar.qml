import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// sakura: the branch laid across the top of the screen. Near-solid dusk-plum
// glass so the strip beats the bright sky; a twig runs under the workspace
// cluster and every workspace is a bud on it — the active one blooms open
// (law 1: state speaks in bloom). Airy light time in the middle; media,
// vitals-as-blossoms, net and battery on the right. Hovering the vitals hangs
// the wish-plaque (sysinfo.qml watches the shared flag file).
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader: true while the session is locked — parks the polls
    property bool occluded: false

    readonly property color cream: pal.text
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color peach: pal.amber
    readonly property color twig:  pal.dim
    readonly property color plum:  pal.glass
    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    readonly property string iconFont: "Symbols Nerd Font"

    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function twigA(a)  { return Qt.rgba(twig.r, twig.g, twig.b, a) }
    function plumA(a)  { return Qt.rgba(plum.r, plum.g, plum.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutSine }

    // shared notched-petal blossom painter (bud 0 → bloom 1)
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.14), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    // a small live blossom — bloom animates, tint follows state
    component Blossom: Canvas {
        id: bc
        property real bloom: 0
        property color tint: root.pink
        property color core: root.creamA(0.9)
        width: 16; height: 16
        Behavior on bloom { NumberAnimation { duration: 500; easing.type: Easing.OutSine } }
        onBloomChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.translate(width / 2, height / 2)
            root.drawBlossom(ctx, width * 0.46, bloom, String(bc.tint), String(bc.core))
        }
        Connections {
            target: root.pal
            function onNeonChanged() { bc.requestPaint() }
            function onTextChanged() { bc.requestPaint() }
        }
    }

    // near-solid plum so the cream stays readable over the brightest frame
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.plumA(0.90) }
            GradientStop { position: 1.0; color: root.plumA(0.78) }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: root.pinkA(0.28)
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT

        // ── left: blossom button + the workspace twig ────────────────────────
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
                    radius: 9
                    color: menuMa.containsMouse ? root.pinkA(0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
                Blossom {
                    anchors.centerIn: parent
                    width: 17; height: 17
                    bloom: menuMa.containsMouse ? 1 : 0.72
                    tint: menuMa.containsMouse ? root.pink : root.pinkA(0.85)
                }
                MouseArea {
                    id: menuMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: root.creamA(0.12)
            }

            // the twig: a thin branch under the slots, each workspace a bud on it
            Item {
                width: wsRow.width
                height: parent.height

                // branch line, with a soft droop at the far end
                Rectangle {
                    anchors.left: wsRow.left
                    anchors.right: wsRow.right
                    y: Math.round(parent.height / 2 + 11)
                    height: 1.5
                    radius: 1
                    color: root.twigA(0.85)
                }

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

                            // the active branch grows to seat the bloom and
                            // the app side by side
                            width: slot.isActive && slot.isOccupied ? 48 : 28
                            height: 34
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutSine } }

                            // stem from the twig up to the bud
                            Rectangle {
                                x: 14 - width / 2
                                y: parent.height / 2 + 4
                                width: 1
                                height: 7
                                color: root.twigA(slot.isActive || slot.isOccupied ? 0.9 : 0.55)
                            }

                            // the bud/blossom riding the stem
                            Blossom {
                                x: 14 - width / 2
                                y: slot.isActive ? 2 : 6
                                width: 15; height: 15
                                bloom: slot.isActive ? 1 : slot.isOccupied ? 0.45 : 0
                                tint: slot.isActive ? root.pink
                                    : slot.isOccupied ? root.pinkA(0.62)
                                    : root.twigA(0.9)
                                Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutSine } }
                            }

                            // the app living on this branch
                            IconImage {
                                x: 14 - width / 2
                                y: -1
                                visible: slot.isOccupied && !slot.isActive
                                width: 16; height: 16
                                source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                                opacity: 0.82
                            }
                            // active ws: icon sits right of the bloom so both read
                            IconImage {
                                x: 26
                                y: 1
                                visible: slot.isOccupied && slot.isActive
                                width: 16; height: 16
                                source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                                opacity: 1
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

        // ── centre: airy time · date ─────────────────────────────────────────
        Row {
            anchors.centerIn: parent
            spacing: 11

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.creamA(0.95)
                font.family: root.sans
                font.weight: Font.Light
                font.pixelSize: 17
                font.letterSpacing: 3
            }
            Blossom {
                anchors.verticalCenter: parent.verticalCenter
                width: 11; height: 11
                bloom: 1
                tint: root.pinkA(0.85)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd MMM d").toLowerCase()
                color: root.skyA(0.85)
                font.family: root.sans
                font.pixelSize: 11
                font.letterSpacing: 2
            }
        }

        // ── right: media · vitals-in-bloom · net · battery ───────────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // now playing: bud pulses while playing, pink progress hairline
            Item {
                visible: root.mediaActive
                width: mediaRow.width
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: mediaRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Blossom {
                        id: mediaBud
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12
                        bloom: root.mediaPlaying ? 1 : 0.3
                        tint: root.mediaPlaying ? root.pink : root.creamA(0.4)
                        SequentialAnimation on opacity {
                            running: root.mediaPlaying && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        id: mediaTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mediaLabel
                        textFormat: Text.PlainText
                        color: root.creamA(0.78)
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 180)
                        font.family: root.sans
                        font.pixelSize: 11
                        font.letterSpacing: 0.4
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    x: mediaTitle.x
                    width: mediaTitle.width * root.mediaProgress
                    height: 1
                    color: root.pinkA(0.6)
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

            // vitals: labeled blossoms — the flower opens as the load climbs.
            // hovering hangs the wish-plaque (sysinfo watches the flag file)
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
                    Blossom {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14
                        bloom: root.cpuPct
                        tint: root.cpuPct > 0.9 ? root.rose : root.cpuPct > 0.75 ? root.peach : root.pinkA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cpu " + Math.round(root.cpuPct * 100) + "%"
                        color: root.creamA(0.75)
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Blossom {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14
                        bloom: root.memPct
                        tint: root.memPct > 0.9 ? root.rose : root.memPct > 0.75 ? root.peach : root.skyA(0.95)
                        core: root.creamA(0.85)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "mem " + Math.round(root.memPct * 100) + "%"
                        color: root.creamA(0.75)
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(root.connType === "ethernet" ? 0xF059F
                    : root.connType === "wifi" ? 0xF05A9 : 0xF092F)
                font.family: root.iconFont
                font.pixelSize: 13
                color: root.connType === "none" ? root.rose : root.skyA(0.9)
            }

            Row {
                visible: root.batPct >= 0
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                Blossom {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    bloom: root.batPct / 100
                    tint: root.batPct < 20 && !root.batCharging ? root.rose
                        : root.batCharging ? root.peach : root.pinkA(0.8)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batPct + "%" + (root.batCharging ? " ↑" : "")
                    color: root.creamA(0.68)
                    font.family: root.sans
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // hover flag shared with sysinfo.qml — it hangs the plaque while this reads "1"
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
        return a ? t + "  ·  " + a : t
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

    // ── vitals + net + battery ───────────────────────────────────────────────
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
