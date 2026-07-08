import QtQuick
import Quickshell
import Quickshell.Io

// fuel: pump-station diagnostic placard, bolted into the dark right side of
// the forecourt. A chamfered service card with the canopy's bent neon stripe
// on top; every level meter is a run of 45°-slanted stripe cells (the pump
// band tilted on its side) and the big numbers are seven-segment tubes.
//   OCTANE  — CPU % (+ temp, load)          TURBO — GPU (nvidia only)
//   TANK    — MEM as a fuel gauge, E → F    RESERVE — battery (laptops)
//   FLOW    — net rates, L/min style        footer — uptime, self-serve sign
// Self-contained: /proc + nmcli + nvidia-smi polled here, hidden when absent.
Item {
    id: root
    anchors.fill: parent

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
    function iceA(a) { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    function tone(v, warn, crit) {
        return v >= crit ? red : v >= warn ? amber : neon
    }
    function pct(v) { return v < 0 ? "--" : v + "%" }

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property real load1: 0
    property int cpuTemp: -1

    property int ramPercent: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    property bool hasGpu: false
    property int gpuPercent: -1
    property int gpuTemp: -1
    property real gpuVramUsed: 0
    property real gpuVramTotal: 0

    property bool hasBattery: false
    property int batteryPercent: -1
    property bool batteryCharging: false

    property bool online: false
    property string connName: ""
    property string connType: ""
    property string uptimeText: "—"

    property real rxRate: 0
    property real txRate: 0
    property real prevRx: -1
    property real prevTx: -1

    property real prevTotal: 0
    property real prevIdle: 0

    // boot-in
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // hover reveal — the bar's DIAG label writes "1"/"0" to this flag file
    // while hovered; the placard stays off the forecourt until then
    property bool hoverShown: false
    property bool pinShown: false
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    property FileView _sysFlag: FileView {
        id: sysFlag
        path: root.sysFlagPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.hoverShown = sysFlag.text().trim() === "1"
    }
    // Super+. pin — the shell writes "1"/"0" here (`qs ipc call sysinfo toggle`);
    // pinned keeps the panel up without hovering
    readonly property string pinFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-pin"
    }
    property FileView _pinFlag: FileView {
        id: pinFlag
        path: root.pinFlagPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.pinShown = pinFlag.text().trim() === "1"
    }

    // ── pollers ─────────────────────────────────────────────────────────────
    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 6000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true; loadProc.running = true }
    }
    Timer {
        interval: 12000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseStat(text) }
    }
    function parseStat(raw) {
        const f = raw.trim().split(/\s+/).slice(1).map(Number)
        if (f.length < 5) return
        const idle = f[3] + f[4]
        const total = f.reduce((a, b) => a + b, 0)
        const dT = total - prevTotal, dI = idle - prevIdle
        if (prevTotal > 0 && dT > 0) cpuPercent = Math.round(100 * (dT - dI) / dT)
        prevTotal = total; prevIdle = idle
    }

    Process {
        id: loadProc
        command: ["cat", "/proc/loadavg"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.load1 = parseFloat(text.trim().split(/\s+/)[0]) || 0 }
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseMem(text) }
    }
    function parseMem(raw) {
        let total = 0, avail = 0
        for (const line of raw.split("\n")) {
            if (line.startsWith("MemTotal:")) total = parseInt(line.replace(/\D+/g, ""))
            else if (line.startsWith("MemAvailable:")) avail = parseInt(line.replace(/\D+/g, ""))
        }
        if (total > 0) {
            ramPercent = Math.round(100 * (total - avail) / total)
            ramTotalGb = total / 1048576
            ramUsedGb = (total - avail) / 1048576
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case \"$(cat $h/name 2>/dev/null)\" in coretemp|k10temp|zenpower) cat $h/temp1_input 2>/dev/null; break;; esac; done"]
        running: false
        stdout: StdioCollector { onStreamFinished: {
            const v = parseInt(text.trim())
            root.cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
        } }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseGpu(text) }
    }
    function parseGpu(raw) {
        const line = raw.trim().split("\n")[0] || ""
        const f = line.split(",").map(s => parseFloat(s))
        if (f.length < 4 || isNaN(f[0])) { hasGpu = false; return }
        hasGpu = true
        gpuPercent = Math.round(f[0])
        gpuTemp = Math.round(f[1])
        gpuVramUsed = f[2] / 1024
        gpuVramTotal = f[3] / 1024
    }

    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseBattery(text) }
    }
    function parseBattery(raw) {
        const lines = raw.trim().split("\n")
        const cap = parseInt(lines[0])
        if (lines[0] === "" || isNaN(cap)) { hasBattery = false; return }
        hasBattery = true
        batteryPercent = cap
        batteryCharging = (lines[1] || "").trim() === "Charging"
    }

    Process {
        id: devProc
        command: ["cat", "/proc/net/dev"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseDev(text) }
    }
    function parseDev(raw) {
        let rx = 0, tx = 0
        for (const line of raw.split("\n")) {
            const i = line.indexOf(":")
            if (i < 0) continue
            if (line.slice(0, i).trim() === "lo") continue
            const f = line.slice(i + 1).trim().split(/\s+/).map(Number)
            rx += f[0] || 0
            tx += f[8] || 0
        }
        if (prevRx >= 0) {
            rxRate = Math.max(0, (rx - prevRx) / 2)
            txRate = Math.max(0, (tx - prevTx) / 2)
        }
        prevRx = rx; prevTx = tx
    }
    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s"
                            : Math.round(b / 1024) + " KB/s"
    }

    Process {
        id: upProc
        command: ["cat", "/proc/uptime"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseUptime(text) }
    }
    function parseUptime(raw) {
        let s = Math.floor(parseFloat(raw.trim().split(/\s+/)[0]) || 0)
        const d = Math.floor(s / 86400); s -= d * 86400
        const h = Math.floor(s / 3600);  s -= h * 3600
        const m = Math.floor(s / 60)
        uptimeText = d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseNet(text) }
    }
    function parseNet(raw) {
        const line = raw.trim()
        if (!line) { online = false; connName = ""; connType = ""; return }
        const i = line.lastIndexOf(":")
        connName = line.slice(0, i)
        const t = line.slice(i + 1)
        connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
        online = true
    }

    // ── seven-segment plumbing (small readout digits) ───────────────────────
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
    // a 2–3 digit seven-segment readout ("--" while unknown)
    component SegReadout: Row {
        id: sr
        property int value: -1
        property color lit: root.neon
        spacing: 2.5
        readonly property string str: sr.value < 0 ? "--"
            : String(Math.max(0, Math.min(999, sr.value)))
        Repeater {
            model: sr.str.length
            Item {
                required property int index
                width: 9; height: 16
                readonly property string ch: sr.str[index]
                Repeater {
                    model: 7
                    Rectangle {
                        required property int index
                        readonly property var g: root.segGeom(index, 9, 16, 1.8)
                        readonly property bool lit2: parent.ch >= "0" && parent.ch <= "9"
                            ? root.segMasks[parseInt(parent.ch)][index] === 1
                            : index === 6   // "-" = middle segment only
                        x: g.x; y: g.y; width: g.w; height: g.h
                        radius: 1
                        color: lit2 ? sr.lit : root.ink
                        opacity: lit2 ? 0.95 : 0.10
                    }
                }
            }
        }
    }

    // slanted stripe-cell meter — the pump band tilted 45°
    component SlantMeter: Item {
        id: meter
        property real value: 0        // 0..100
        property color tone2: root.neon
        property int cells: 16
        height: 9
        Row {
            spacing: 3.5
            anchors.verticalCenter: parent.verticalCenter
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, -0.45, 0, 4, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            Repeater {
                model: meter.cells
                Rectangle {
                    required property int index
                    width: 6.5; height: 9
                    readonly property bool lit: index < Math.round(meter.value / 100 * meter.cells)
                    color: meter.tone2
                    opacity: lit ? 0.95 : 0.13
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }
            }
        }
    }

    // label + seg number + unit row
    component StatRow: Item {
        id: strow
        property string label: ""
        property int value: -1
        property string unit: "%"
        property color tone2: root.neon
        width: parent ? parent.width : 0
        height: 18
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: strow.label
            font.family: root.mono
            font.weight: Font.Bold
            font.pixelSize: 10
            font.letterSpacing: 3
            color: root.ice
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            SegReadout { anchors.verticalCenter: parent.verticalCenter; value: strow.value; lit: strow.tone2 }
            Text {
                anchors.bottom: parent.bottom
                text: strow.unit
                font.family: root.mono
                font.pixelSize: 8
                color: root.inkA(0.55)
            }
        }
    }

    // ── the placard, pinned to the dark right edge ──────────────────────────
    Item {
        id: panel
        width: 268
        height: col.implicitHeight + 34
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 26
        anchors.bottomMargin: 34 - 12 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.BottomRight

        // hung on the shop wall with one nail — knocks, rocks, settles
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: 2.6; to: -1.1; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { from: -1.1; to: 0.4; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.4; to: 0; duration: 400; easing.type: Easing.OutSine }
        }

        Canvas {
            id: plate
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { plate.requestPaint() }
                function onDimChanged()  { plate.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, c = 13
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(0, c); ctx.lineTo(c, 0); ctx.lineTo(w - c, 0)
                ctx.lineTo(w, c); ctx.lineTo(w, h); ctx.lineTo(0, h)
                ctx.closePath()
                ctx.fillStyle = "rgba(5,8,12,0.76)"
                ctx.fill()
                ctx.strokeStyle = root.pal.dim
                ctx.globalAlpha = 0.55
                ctx.lineWidth = 1
                ctx.stroke()
                ctx.globalAlpha = 1
                // bent neon stripe along the top
                ctx.beginPath()
                ctx.moveTo(0.8, c + 4); ctx.lineTo(c + 1.5, 1.2)
                ctx.lineTo(w - c - 1.5, 1.2); ctx.lineTo(w - 0.8, c + 4)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = root.pal.neon
                ctx.lineWidth = 4
                ctx.globalAlpha = 0.20
                ctx.stroke()
                ctx.lineWidth = 1.5
                ctx.globalAlpha = 0.95
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 17
            spacing: 8

            // header: PUMP Nº 02 · DIAGNOSTIC + slow-breathing pilot lamp
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: root.amber
                        SequentialAnimation on opacity {
                            running: root.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PUMP Nº 02"
                        font.family: root.mono
                        font.weight: Font.Black
                        font.pixelSize: 11
                        font.letterSpacing: 3
                        color: root.ink
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DIAGNOSTIC"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.iceA(0.6)
                }
            }

            // pump stripe band under the header
            Column {
                width: parent.width
                spacing: 2
                Rectangle { width: parent.width; height: 2; color: root.amber; opacity: 0.75 }
                Rectangle { width: parent.width; height: 2; color: root.neon; opacity: 0.85 }
                Rectangle { width: parent.width; height: 2; color: root.red; opacity: 0.65 }
            }

            Item { width: 1; height: 2 }

            // OCTANE — CPU
            StatRow { label: "OCTANE"; value: root.cpuPercent; tone2: root.tone(root.cpuPercent, 60, 85) }
            SlantMeter { width: parent.width; value: root.cpuPercent < 0 ? 0 : root.cpuPercent; tone2: root.tone(root.cpuPercent, 60, 85) }
            Text {
                anchors.right: parent.right
                text: (root.cpuTemp > 0 ? root.cpuTemp + "°C · " : "") + "LOAD " + root.load1.toFixed(2)
                font.family: root.mono
                font.pixelSize: 8
                color: root.inkA(0.4)
            }

            // TURBO — GPU (nvidia only)
            StatRow {
                visible: root.hasGpu
                height: root.hasGpu ? 18 : 0
                label: "TURBO"; value: root.gpuPercent; tone2: root.tone(root.gpuPercent, 60, 85)
            }
            SlantMeter {
                visible: root.hasGpu
                width: parent.width
                height: root.hasGpu ? 9 : 0
                value: root.gpuPercent < 0 ? 0 : root.gpuPercent
                tone2: root.tone(root.gpuPercent, 60, 85)
            }
            Text {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                anchors.right: parent.right
                text: root.gpuVramUsed.toFixed(1) + " / " + root.gpuVramTotal.toFixed(1) + " GB · " + root.gpuTemp + "°C"
                font.family: root.mono
                font.pixelSize: 8
                color: root.inkA(0.4)
            }

            // TANK — memory as a fuel gauge, E → F
            StatRow { label: "TANK"; value: root.ramPercent; tone2: root.tone(root.ramPercent, 70, 90) }
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "E"
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: 9
                    color: root.red
                    opacity: 0.8
                }
                SlantMeter {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    cells: 14
                    // a fuel gauge reads what's LEFT in the tank
                    value: root.ramPercent < 0 ? 0 : 100 - root.ramPercent
                    tone2: root.ramPercent >= 90 ? root.red : root.ramPercent >= 70 ? root.amber : root.amber
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "F"
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: 9
                    color: root.neon
                    opacity: 0.8
                }
            }
            Text {
                anchors.right: parent.right
                text: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB BURNED"
                font.family: root.mono
                font.pixelSize: 8
                color: root.inkA(0.4)
            }

            // RESERVE — battery (laptops only)
            StatRow {
                visible: root.hasBattery
                height: root.hasBattery ? 18 : 0
                label: "RESERVE"; value: root.batteryPercent
                tone2: root.batteryCharging ? root.ice
                    : root.batteryPercent <= 15 ? root.red
                    : root.batteryPercent <= 30 ? root.amber : root.neon
            }
            SlantMeter {
                visible: root.hasBattery
                width: parent.width
                height: root.hasBattery ? 9 : 0
                value: root.batteryPercent < 0 ? 0 : root.batteryPercent
                tone2: root.batteryCharging ? root.ice
                    : root.batteryPercent <= 15 ? root.red
                    : root.batteryPercent <= 30 ? root.amber : root.neon
            }

            Item { width: 1; height: 2 }
            Rectangle { width: parent.width; height: 1; color: root.dim; opacity: 0.5 }

            // FLOW — net
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FLOW"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 10
                        font.letterSpacing: 3
                        color: root.ice
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.online ? root.iceA(0.8) : root.red
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "LINE DOWN"
                        font.family: root.mono
                        font.pixelSize: 9
                        color: root.online ? root.iceA(0.8) : root.red
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓ " + root.fmtRate(root.rxRate) + "  ↑ " + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 8
                    color: root.amber
                    opacity: 0.9
                }
            }

            // footer
            Item {
                width: parent.width
                height: 12
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "UP " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 8
                    color: root.inkA(0.4)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// MIDNIGHT FUEL STOP"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.neon
                    opacity: 0.5
                }
            }
        }
    }
}
