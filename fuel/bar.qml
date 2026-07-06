import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

// fuel: bottom pump-readout strip. Chamfered station plates float over the
// wet forecourt, each with the canopy's neon stripe bent 45° over its top
// corners; the retro 3-stripe pump band grounds the whole screen edge.
//   left   — FUEL roundel (stripe band, click: control popup) + a "NOW
//            FUELING" mpris chip with a neon progress hose
//   center — PUMP BAYS: workspaces as bay numbers; occupied bays lit orange,
//            the active bay carries a bent-corner neon underline
//   right  — FLOW (net rate) · LINE (connection) · RESERVE (battery) plate,
//            and the time as a mini seven-segment price display
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli polled here.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color neon:  pal.neon
    readonly property color ice:   pal.cyan
    readonly property color red:   pal.magenta
    readonly property color amber: pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function neonA(a) { return Qt.rgba(neon.r, neon.g, neon.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // boot-in: plates rise off the forecourt
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 750; easing.type: Easing.OutCubic }
    readonly property real bootLate: Math.max(0, (bootT - 0.3) / 0.7)

    // ── seven-segment plumbing (mini price digits) ──────────────────────────
    readonly property var segMasks: [
        [1,1,1,1,1,1,0], [0,1,1,0,0,0,0], [1,1,0,1,1,0,1], [1,1,1,1,0,0,1],
        [0,1,1,0,0,1,1], [1,0,1,1,0,1,1], [1,0,1,1,1,1,1], [1,1,1,0,0,0,0],
        [1,1,1,1,1,1,1], [1,1,1,1,0,1,1]
    ]
    function segGeom(i, W, H, t) {
        switch (i) {
        case 0: return { x: t * 0.75, y: 0,                w: W - t * 1.5, h: t }
        case 1: return { x: W - t,    y: t * 0.65,         w: t,           h: H / 2 - t }
        case 2: return { x: W - t,    y: H / 2 + t * 0.35, w: t,           h: H / 2 - t }
        case 3: return { x: t * 0.75, y: H - t,            w: W - t * 1.5, h: t }
        case 4: return { x: 0,        y: H / 2 + t * 0.35, w: t,           h: H / 2 - t }
        case 5: return { x: 0,        y: t * 0.65,         w: t,           h: H / 2 - t }
        default: return { x: t * 0.75, y: H / 2 - t / 2,   w: W - t * 1.5, h: t }
        }
    }
    component MiniDigit: Item {
        id: md
        property int value: 8
        width: 10
        height: 18
        readonly property real t: 2
        readonly property var mask: (md.value >= 0 && md.value <= 9)
            ? root.segMasks[md.value] : [0,0,0,0,0,0,0]
        Repeater {
            model: 7
            Rectangle {
                required property int index
                readonly property var g: root.segGeom(index, md.width, md.height, md.t)
                x: g.x; y: g.y; width: g.w; height: g.h
                radius: 1
                color: md.mask[index] ? root.neon : root.ink
                opacity: md.mask[index] ? 0.95 : 0.10
            }
        }
    }

    // chamfered station plate: top corners cut, neon stripe bending over them
    component Plate: Item {
        id: plateRoot
        property color stripe: root.neon
        property real stripeAlpha: 0.9
        Canvas {
            id: plateCv
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { plateCv.requestPaint() }
                function onCyanChanged() { plateCv.requestPaint() }
                function onDimChanged()  { plateCv.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, c = 8
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(0, c); ctx.lineTo(c, 0); ctx.lineTo(w - c, 0)
                ctx.lineTo(w, c); ctx.lineTo(w, h); ctx.lineTo(0, h)
                ctx.closePath()
                ctx.fillStyle = "rgba(5,8,12,0.74)"
                ctx.fill()
                ctx.strokeStyle = root.pal.dim
                ctx.globalAlpha = 0.5
                ctx.lineWidth = 1
                ctx.stroke()
                ctx.globalAlpha = 1
                // the bent neon stripe
                ctx.beginPath()
                ctx.moveTo(0.5, c + 3); ctx.lineTo(c + 1, 0.8)
                ctx.lineTo(w - c - 1, 0.8); ctx.lineTo(w - 0.5, c + 3)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = plateRoot.stripe
                ctx.lineWidth = 3.2
                ctx.globalAlpha = 0.16 * plateRoot.stripeAlpha
                ctx.stroke()
                ctx.lineWidth = 1.3
                ctx.globalAlpha = plateRoot.stripeAlpha
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }
    }

    // ── the 3-stripe pump band, grounding the screen's bottom edge ──────────
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        opacity: 0.30 * root.bootT
        Rectangle { width: parent.width; height: 1; color: root.amber }
        Rectangle { width: parent.width; height: 1; color: root.neon }
        Rectangle { width: parent.width; height: 1; color: root.red }
    }

    // ── left: FUEL roundel + now-fueling chip ───────────────────────────────
    Plate {
        id: roundel
        height: 32
        width: roundelRow.width + 24
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8 * (1 - root.bootT)
        opacity: root.bootT

        Row {
            id: roundelRow
            anchors.centerIn: parent
            spacing: 8
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Rectangle { width: 16; height: 2; color: root.amber }
                Rectangle { width: 16; height: 2; color: root.neon }
                Rectangle { width: 16; height: 2; color: root.red }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "FUEL"
                color: roundelMa.containsMouse ? root.ink : root.inkA(0.85)
                font.family: root.mono
                font.weight: Font.Black
                font.pixelSize: 12
                font.letterSpacing: 4
            }
        }
        MouseArea {
            id: roundelMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
        }
    }

    Plate {
        id: media
        stripe: root.ice
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        height: 32
        width: active ? mediaRow.width + 24 : 0
        anchors.left: roundel.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8 * (1 - root.bootLate)
        opacity: root.bootLate

        property real progress: 0
        function updateProgress() {
            const p = media.player
            media.progress = (p && p.length > 0 && p.position >= 0)
                ? Math.min(1, p.position / p.length) : 0
        }
        Timer {
            interval: 1000; repeat: true
            running: media.playing && root.visible
            triggeredOnStart: true
            onTriggered: media.updateProgress()
        }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: media.playing ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
                color: root.amber
                font.family: root.icon
                font.pixelSize: 13
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: media.playing ? "NOW FUELING" : "PUMP PAUSED"
                    color: root.iceA(0.65)
                    font.family: root.mono
                    font.pixelSize: 7
                    font.letterSpacing: 2
                }
                Text {
                    width: Math.min(implicitWidth, 210)
                    elide: Text.ElideRight
                    text: {
                        if (!media.active) return ""
                        const t = media.player.trackTitle || "—"
                        const a = media.player.trackArtist
                        return a ? t + " · " + a : t
                    }
                    color: root.ice
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 0.5
                }
            }
        }

        // the hose: progress underline along the plate's bottom edge
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 2
            anchors.bottomMargin: 1
            height: 2
            width: Math.max(0, (parent.width - 6) * media.progress)
            color: root.neon
            opacity: 0.85
            Behavior on width { NumberAnimation { duration: 900 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
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

    // ── center: PUMP BAYS (workspaces) ──────────────────────────────────────
    Plate {
        id: bays
        height: 32
        width: bayRow.width + 30
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8 * (1 - root.bootT)
        opacity: root.bootT

        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1

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

        Row {
            id: bayRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BAY"
                color: root.iceA(0.55)
                font.family: root.mono
                font.pixelSize: 8
                font.letterSpacing: 3
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: bays.wsCount
                    delegate: Item {
                        id: slot
                        required property int index
                        readonly property int wsId: bays.pageBase + index
                        readonly property bool isActive: bays.activeWsId === wsId
                        readonly property bool isOccupied: Hyprland.toplevels.values
                            .some(t => (t.workspace?.id ?? -1) === slot.wsId)

                        width: 18
                        height: 26

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            text: (slot.wsId % 10).toString()
                            color: slot.isActive ? root.ink : slot.isOccupied ? root.neon : root.ink
                            opacity: slot.isActive ? 1.0 : slot.isOccupied ? 0.9 : 0.22
                            font.family: root.mono
                            font.weight: slot.isActive ? Font.Black : Font.Bold
                            font.pixelSize: 12
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        // active bay: neon underline that bends up at both ends
                        Canvas {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18; height: 7
                            visible: slot.isActive
                            onVisibleChanged: if (visible) requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.beginPath()
                                ctx.moveTo(1, 1); ctx.lineTo(4.5, 5.5)
                                ctx.lineTo(13.5, 5.5); ctx.lineTo(17, 1)
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.strokeStyle = root.neon
                                ctx.lineWidth = 3
                                ctx.globalAlpha = 0.25
                                ctx.stroke()
                                ctx.lineWidth = 1.4
                                ctx.globalAlpha = 1
                                ctx.stroke()
                            }
                        }
                        // occupied, not active: a small resting amber pip
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: slot.isOccupied && !slot.isActive
                            width: 5; height: 2; radius: 1
                            color: root.amber
                            opacity: 0.6
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                        }
                    }
                }
            }
        }
    }

    // ── right: gauges plate + price-display clock ───────────────────────────
    Plate {
        id: gauges
        height: 32
        width: gaugeRow.width + 26
        anchors.right: priceClock.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8 * (1 - root.bootLate)
        opacity: root.bootLate
        stripe: root.amber

        // net rates from /proc/net/dev
        property real rxRate: 0
        property real prevRx: -1
        Timer {
            interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true
            onTriggered: devProc.running = true
        }
        Process {
            id: devProc
            command: ["cat", "/proc/net/dev"]
            running: false
            stdout: StdioCollector { onStreamFinished: gauges.parseDev(text) }
        }
        function parseDev(raw) {
            let rx = 0
            for (const line of raw.split("\n")) {
                const i = line.indexOf(":")
                if (i < 0) continue
                if (line.slice(0, i).trim() === "lo") continue
                rx += Number(line.slice(i + 1).trim().split(/\s+/)[0]) || 0
            }
            if (prevRx >= 0) rxRate = Math.max(0, (rx - prevRx) / 3)
            prevRx = rx
        }
        function fmtRate(b) {
            return b >= 1048576 ? (b / 1048576).toFixed(1) + "M"
                                : Math.round(b / 1024) + "K"
        }

        // connection via nmcli
        property bool online: false
        property string connType: ""
        Timer {
            interval: 15000; running: root.visible; repeat: true; triggeredOnStart: true
            onTriggered: netProc.running = true
        }
        Process {
            id: netProc
            command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
            running: false
            stdout: StdioCollector { onStreamFinished: gauges.parseNet(text) }
        }
        function parseNet(raw) {
            const line = raw.trim()
            if (!line) { online = false; connType = ""; return }
            const t = line.slice(line.lastIndexOf(":") + 1)
            connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
            online = true
        }

        // battery (hidden on desktops)
        property bool hasBattery: false
        property int batteryPercent: -1
        property bool batteryCharging: false
        Timer {
            interval: 30000; running: root.visible; repeat: true; triggeredOnStart: true
            onTriggered: batProc.running = true
        }
        Process {
            id: batProc
            command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
            running: false
            stdout: StdioCollector { onStreamFinished: gauges.parseBattery(text) }
        }
        function parseBattery(raw) {
            const lines = raw.trim().split("\n")
            const cap = parseInt(lines[0])
            if (lines[0] === "" || isNaN(cap)) { hasBattery = false; return }
            hasBattery = true
            batteryPercent = cap
            batteryCharging = (lines[1] || "").trim() === "Charging"
        }

        Row {
            id: gaugeRow
            anchors.centerIn: parent
            spacing: 10

            // FLOW: incoming rate, styled as a pump flow readout
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "FLOW"
                    color: root.iceA(0.55)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: gauges.fmtRate(gauges.rxRate)
                    color: root.amber
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: 10
                }
            }

            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: root.dim; opacity: 0.6 }

            // LINE: connection glyph
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: gauges.online
                    ? String.fromCodePoint(gauges.connType === "eth" ? 0xF059F : 0xF05A9)
                    : String.fromCodePoint(0xF092F)
                color: gauges.online ? root.ice : root.red
                font.family: root.icon
                font.pixelSize: 12
            }

            // RESERVE: battery, laptops only
            Row {
                visible: gauges.hasBattery
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: root.dim; opacity: 0.6 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: gauges.batteryCharging ? String.fromCodePoint(0xF0084)
                        : String.fromCodePoint(0xF0079 + Math.max(0, Math.min(9, Math.floor(gauges.batteryPercent / 10))))
                    color: gauges.batteryCharging ? root.ice
                        : gauges.batteryPercent <= 15 ? root.red
                        : gauges.batteryPercent <= 30 ? root.amber : root.neon
                    font.family: root.icon
                    font.pixelSize: 12
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: gauges.batteryPercent + "%"
                    color: root.inkA(0.75)
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }
        }
    }

    // the time as a mini price display
    Plate {
        id: priceClock
        height: 32
        width: clockRow.width + 26
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8 * (1 - root.bootT)
        opacity: root.bootT

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 4
            MiniDigit { anchors.verticalCenter: parent.verticalCenter; value: parseInt(root.hh[0]) }
            MiniDigit { anchors.verticalCenter: parent.verticalCenter; value: parseInt(root.hh[1]) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Rectangle { width: 2; height: 2; color: root.neon }
                Rectangle { width: 2; height: 2; color: root.neon }
            }
            MiniDigit { anchors.verticalCenter: parent.verticalCenter; value: parseInt(root.mm[0]) }
            MiniDigit { anchors.verticalCenter: parent.verticalCenter; value: parseInt(root.mm[1]) }
        }
    }
}
