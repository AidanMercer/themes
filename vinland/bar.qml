import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// vinland: vertical left bar — a strip of night glass with an ice seam.
// Top: the north star (Super+M popup) + workspaces, the active one marked by
// a gold star. Bottom: now-playing with a rotated title and an ice progress
// ring, cpu/mem/battery micro meters, stacked clock.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal

    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color amber: pal.amber
    readonly property color night: pal.glass
    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    readonly property string iconFont: "Symbols Nerd Font"

    function snowA(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function tintA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    // gentle boot-in: everything drifts in from the left
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // ── the strip: night glass + an ice seam on the window side ─────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.night.r, root.night.g, root.night.b, 0.72) }
            GradientStop { position: 1.0; color: Qt.rgba(root.night.r, root.night.g, root.night.b, 0.58) }
        }
    }
    Rectangle {
        width: 1
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        color: root.iceA(0.16)
    }

    Item {
        anchors.fill: parent
        opacity: root.bootT
        transform: Translate { x: -8 * (1 - root.bootT) }

        // ── top: north star + workspaces ─────────────────────────────────────
        Column {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Item {
                width: 30; height: 30
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: starMa.containsMouse ? root.iceA(0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Canvas {
                    id: northStar
                    anchors.centerIn: parent
                    width: 16; height: 16
                    property color tint: starMa.containsMouse ? root.gold : root.ice
                    onTintChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const c = width / 2, R = width / 2
                        ctx.beginPath()
                        ctx.moveTo(c, c - R)
                        ctx.quadraticCurveTo(c, c, c + R, c)
                        ctx.quadraticCurveTo(c, c, c, c + R)
                        ctx.quadraticCurveTo(c, c, c - R, c)
                        ctx.quadraticCurveTo(c, c, c, c - R)
                        ctx.closePath()
                        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.95)
                        ctx.fill()
                    }
                    Connections {
                        target: root.pal
                        function onNeonChanged() { northStar.requestPaint() }
                        function onCyanChanged() { northStar.requestPaint() }
                    }
                }
                MouseArea {
                    id: starMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }

            Stave { }

            Item {
                width: 28
                height: wsCol.height
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    id: wsCol
                    spacing: 2

                    readonly property int wsCount: 10
                    readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
                    readonly property int pageBase: activeWsId >= 1
                        ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
                        : 1

                    // keep the .desktop database observed so heuristicLookup() works
                    readonly property int _keepAlive: DesktopEntries.applications.values.length

                    Repeater {
                        model: wsCol.wsCount
                        delegate: Item {
                            id: slot
                            required property int index
                            readonly property int wsId: wsCol.pageBase + index
                            readonly property bool isActive: wsCol.activeWsId === wsId
                            readonly property var windowsHere: Hyprland.toplevels.values
                                .filter(t => (t.workspace?.id ?? -1) === wsId)
                            readonly property bool isOccupied: windowsHere.length > 0

                            width: 28
                            height: 26

                            // faint ice pill behind the active slot
                            Rectangle {
                                anchors.centerIn: parent
                                width: 26; height: 24; radius: 8
                                color: root.iceA(slot.isActive ? 0.13 : 0)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            // empty: a faint snow dot; the gold star while active
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !slot.isOccupied && !slot.isActive
                                width: 4; height: 4; radius: 2
                                color: root.snowA(0.26)
                            }
                            Canvas {
                                id: slotStar
                                anchors.centerIn: parent
                                visible: !slot.isOccupied && slot.isActive
                                width: 11; height: 11
                                scale: visible ? 1 : 0.4
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                onVisibleChanged: if (visible) requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    const c = width / 2, R = width / 2
                                    ctx.beginPath()
                                    ctx.moveTo(c, c - R)
                                    ctx.quadraticCurveTo(c, c, c + R, c)
                                    ctx.quadraticCurveTo(c, c, c, c + R)
                                    ctx.quadraticCurveTo(c, c, c - R, c)
                                    ctx.quadraticCurveTo(c, c, c, c - R)
                                    ctx.closePath()
                                    ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.95)
                                    ctx.fill()
                                }
                                Connections {
                                    target: root.pal
                                    function onCyanChanged() { slotStar.requestPaint() }
                                }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                visible: slot.isOccupied
                                width: 15; height: 15
                                source: slot.isOccupied ? root.iconForWindows(slot.windowsHere) : ""
                                opacity: slot.isActive ? 1.0 : 0.5
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

                // wheel anywhere on the strip cycles workspaces
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (w) => Hyprland.dispatch(w.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
                }
            }
        }

        // ── bottom: media · meters · clock ───────────────────────────────────
        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9

            Column {
                visible: root.mediaActive
                spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter

                // track title, reading bottom-to-top along the bar
                Item {
                    width: 14
                    height: Math.min(titleText.implicitWidth, 130)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        id: titleText
                        anchors.centerIn: parent
                        width: parent.height
                        rotation: -90
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: root.mediaLabel
                        textFormat: Text.PlainText
                        color: root.snowA(0.55)
                        font.family: root.sans
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 0.4
                    }
                }

                // ice progress ring around play/pause, gold while playing
                Item {
                    width: 26; height: 26
                    anchors.horizontalCenter: parent.horizontalCenter

                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real p: root.mediaProgress
                        onPChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const c = width / 2, r = c - 2
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.arc(c, c, r, 0, 2 * Math.PI)
                            ctx.strokeStyle = root.snowA(0.14)
                            ctx.stroke()
                            if (p > 0.005) {
                                ctx.beginPath()
                                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * p)
                                ctx.strokeStyle = root.ice
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                        Connections {
                            target: root.pal
                            function onNeonChanged() { ring.requestPaint() }
                            function onTextChanged() { ring.requestPaint() }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.mediaPlaying ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
                        font.family: root.iconFont
                        font.pixelSize: 10
                        color: root.mediaPlaying ? root.gold : root.ice
                        opacity: mediaMa.containsMouse ? 1.0 : 0.85
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: mediaMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.mediaActive && root.player.canTogglePlaying) root.player.togglePlaying()
                        onWheel: (w) => {
                            if (!root.mediaActive) return
                            // shift+scroll nudges the live lyric offset
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
            }

            Stave { visible: root.mediaActive }

            Column {
                spacing: 4
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Meter { value: root.cpuPct }
                    Meter { value: root.memPct; tint: root.snowA(0.45) }
                    Meter {
                        visible: root.batPct >= 0
                        value: Math.max(0, root.batPct) / 100
                        autoWarn: false
                        tint: root.batPct >= 0 && root.batPct < 20 && !root.batCharging ? root.rose
                            : root.batCharging ? root.gold : root.tintA(root.pal.dim, 0.9)
                    }
                }
                Text {
                    visible: root.batPct >= 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.batPct + (root.batCharging ? "+" : "")
                    color: root.snowA(0.40)
                    font.family: root.sans
                    font.pixelSize: 8
                    font.weight: Font.Medium
                }
            }

            Stave { }

            Column {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: root.snow
                    font.family: root.mono
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: 4; height: 4
                    rotation: 45
                    color: root.gold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: root.snowA(0.55)
                    font.family: root.mono
                    font.pixelSize: 13
                }
                Item { width: 1; height: 2 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "ddd").toUpperCase()
                    color: root.snowA(0.38)
                    font.family: root.sans
                    font.pixelSize: 7
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                }
            }
        }
    }

    // a carved divider: hairline with a single notch
    component Stave: Item {
        width: 16; height: 5
        anchors.horizontalCenter: parent.horizontalCenter
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: root.iceA(0.18)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1; height: 5
            rotation: 20
            color: root.iceA(0.30)
        }
    }

    component Meter: Item {
        property real value: 0
        property color tint: root.ice
        property bool autoWarn: true
        width: 4; height: 26

        Rectangle { anchors.fill: parent; radius: 2; color: root.snowA(0.10) }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            radius: 2
            height: Math.max(3, parent.height * Math.min(1, parent.value))
            color: parent.autoWarn && parent.value > 0.9 ? root.rose
                 : parent.autoWarn && parent.value > 0.75 ? root.amber
                 : parent.tint
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 300 } }
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

    // ── cpu / mem / battery ─────────────────────────────────────────────────
    property real cpuPct: 0
    property real memPct: 0
    property int batPct: -1
    property bool batCharging: false
    property var _prevCpu: null

    function parseStats(out) {
        const lines = out.trim().split("\n")
        let memT = 0, memA = 0
        for (const raw of lines) {
            const l = raw.trim()
            if (l.startsWith("cpu ")) {
                const f = l.split(/\s+/).slice(1).map(Number)
                const tot = f.reduce((a, b) => a + b, 0)
                const idle = f[3] + (f[4] || 0)
                if (root._prevCpu) {
                    const dt = tot - root._prevCpu.tot, di = idle - root._prevCpu.idle
                    if (dt > 0) root.cpuPct = Math.max(0, Math.min(1, (dt - di) / dt))
                }
                root._prevCpu = { tot: tot, idle: idle }
            } else if (l.startsWith("MemTotal")) memT = parseInt(l.split(/\s+/)[1])
            else if (l.startsWith("MemAvailable")) memA = parseInt(l.split(/\s+/)[1])
            else if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
        }
        if (memT > 0) root.memPct = Math.max(0, Math.min(1, 1 - memA / memT))
    }
    Process {
        id: statProc
        command: ["bash", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; " +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Timer {
        interval: 2500; repeat: true; running: true; triggeredOnStart: true
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
