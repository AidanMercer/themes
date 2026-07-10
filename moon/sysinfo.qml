import QtQuick
import Quickshell
import Quickshell.Io

// Cyberpunk: Edgerunners system readout for the "moon" wallpaper.
//
// Loaded by the ThemeSysInfo overlay while this wallpaper is showing. A full-screen
// click-through scenery layer; the actual widget is a chamfered HUD panel pinned
// bottom-right. Reads everything from /proc + nmcli, no repo modules (self-contained).
//   CPU  — aggregate %, a segmented meter, per-core bars, temp + load averages
//   GPU  — nvidia util %, meter, vram + temp (hidden without nvidia-smi)
//   MEM  — used %, meter, used / total GB
//   PWR  — battery %, meter, charge glyph (hidden on desktops with no battery)
//   NET  — connection + up/down rates, uptime below
Item {
    id: root
    anchors.fill: parent

    // always-on readout: desktop scenery, not a popup — the loader parks this
    // under windows on the Bottom layer instead of floating it over them
    readonly property bool desktopSysinfo: true

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color neon:    pal.neon
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta
    readonly property color amber:   pal.amber
    readonly property color dim:     pal.dim
    readonly property string mono:   "Noto Sans Mono"
    readonly property string icon:   "Symbols Nerd Font"

    // pushed live by the loader: true while the session is locked → stop polling
    property bool occluded: false

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property var coreLoads: []
    property real load1: 0
    property real load5: 0
    property real load15: 0

    property int ramPercent: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    property bool online: false
    property string connName: ""
    property string connType: ""
    property string uptimeText: "—"

    property bool hasGpu: false
    property int gpuPercent: -1
    property int gpuTemp: -1
    property real gpuVramUsed: 0
    property real gpuVramTotal: 0

    property int cpuTemp: -1

    property real rxRate: 0        // bytes/s, all interfaces minus lo
    property real txRate: 0
    property real prevRx: -1
    property real prevTx: -1

    // boot-in: the panel rises in once on load; the meters then fill naturally
    // as the first polls land (their opacity/height behaviors do the rest)
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // remember last /proc/stat tallies so we can diff into a percentage
    property real prevTotal: 0
    property real prevIdle: 0
    property var prevCoreTotal: ({})
    property var prevCoreIdle: ({})

    function tone(v, warn, crit) {
        return v >= crit ? magenta : v >= warn ? amber : neon
    }

    // ── pollers ─────────────────────────────────────────────────────────────
    Timer {
        interval: 1500; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; loadProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 5000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
    }
    Timer {
        interval: 10000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: statProc
        command: ["cat", "/proc/stat"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseStat(text) }
    }
    function parseStat(raw) {
        const cores = []
        const nextCoreTotal = {}, nextCoreIdle = {}
        for (const line of raw.split("\n")) {
            if (!line.startsWith("cpu")) break               // cpu lines are first
            const parts = line.trim().split(/\s+/)
            const key = parts[0]
            const f = parts.slice(1).map(Number)
            if (f.length < 5) continue
            const idle = f[3] + f[4]
            const total = f.reduce((a, b) => a + b, 0)
            if (key === "cpu") {
                const dT = total - prevTotal, dI = idle - prevIdle
                if (prevTotal > 0 && dT > 0) cpuPercent = Math.round(100 * (dT - dI) / dT)
                prevTotal = total; prevIdle = idle
            } else {
                const pT = prevCoreTotal[key] ?? 0, pI = prevCoreIdle[key] ?? 0
                const dT = total - pT, dI = idle - pI
                if (pT > 0 && dT > 0) cores.push(Math.round(100 * (dT - dI) / dT))
                else cores.push(0)
                nextCoreTotal[key] = total; nextCoreIdle[key] = idle
            }
        }
        prevCoreTotal = nextCoreTotal; prevCoreIdle = nextCoreIdle
        if (cores.length > 0) coreLoads = cores
    }

    Process {
        id: loadProc
        command: ["cat", "/proc/loadavg"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseLoad(text) }
    }
    function parseLoad(raw) {
        const f = raw.trim().split(/\s+/)
        load1 = parseFloat(f[0]) || 0
        load5 = parseFloat(f[1]) || 0
        load15 = parseFloat(f[2]) || 0
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
    function batteryGlyph(level, charging) {
        if (charging) return String.fromCodePoint(0xF0084)
        if (level >= 95) return String.fromCodePoint(0xF0079)
        if (level < 10) return String.fromCodePoint(0xF0083)
        return String.fromCodePoint(0xF0079 + Math.floor(level / 10))
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
        if (prevRx >= 0) {                        // diff over the 1.5s poll
            rxRate = Math.max(0, (rx - prevRx) / 1.5)
            txRate = Math.max(0, (tx - prevTx) / 1.5)
        }
        prevRx = rx; prevTx = tx
    }
    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s"
                            : Math.round(b / 1024) + " KB/s"
    }

    // nvidia only (the desktop) — the /sys/module/nvidia guard means no probe
    // fires on the amd laptop (same disk, nvidia-smi binary present), and no
    // output hides the whole GPU section
    Process {
        id: gpuProc
        command: ["sh", "-c", "[ -d /sys/module/nvidia ] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true"]
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
        id: tempProc
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case \"$(cat $h/name 2>/dev/null)\" in coretemp|k10temp|zenpower) cat $h/temp1_input 2>/dev/null; break;; esac; done"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseTemp(text) }
    }
    function parseTemp(raw) {
        const v = parseInt(raw.trim())
        cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
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

    function pct(v) { return v < 0 ? "--" : v + "%" }

    // ── reusable bits ─────────────────────────────────────────────────────────
    // a segmented level meter, 0..100
    component Meter: Row {
        id: meter
        property real value: 0
        property color tone: root.neon
        property int cells: 18
        spacing: 3
        Repeater {
            model: meter.cells
            Rectangle {
                width: 6; height: 9
                readonly property bool lit: index < Math.round(meter.value / 100 * meter.cells)
                color: meter.tone
                opacity: lit ? 0.95 : 0.14
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
        }
    }

    // section label + big percentage, sharing a tone
    component StatLine: Item {
        property string label: ""
        property string glyph: ""
        property int value: -1
        property color tone: root.neon
        implicitHeight: 18
        width: parent ? parent.width : 0

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: glyph !== ""
                text: glyph
                font.family: root.icon
                font.pixelSize: 13
                color: tone
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 2
                color: root.cyan
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct(value)
            font.family: root.mono
            font.weight: Font.Bold
            font.pixelSize: 15
            color: tone
        }
    }

    // ── the panel, pinned bottom-right ────────────────────────────────────────
    Item {
        id: panel
        width: 272
        height: col.implicitHeight + 28
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 26
        anchors.bottomMargin: 26 - 12 * (1 - root.bootT)
        opacity: root.bootT

        scale: pal.uiScale
        transformOrigin: Item.BottomRight

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, c = 13
                ctx.reset()
                ctx.beginPath()
                ctx.moveTo(c, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - c)
                ctx.lineTo(w - c, h); ctx.lineTo(0, h); ctx.lineTo(0, c)
                ctx.closePath()
                ctx.fillStyle = "rgba(7,7,10,0.72)"
                ctx.fill()
                ctx.strokeStyle = root.neon
                ctx.lineWidth = 1.4
                ctx.stroke()
                // cyan inner rule along the top
                ctx.beginPath()
                ctx.moveTo(14, 4); ctx.lineTo(w - 6, 4)
                ctx.strokeStyle = "rgba(0,229,255,0.5)"
                ctx.lineWidth = 1
                ctx.stroke()
                // corner ticks, bottom-right
                ctx.beginPath()
                ctx.moveTo(w - 4, h - 22); ctx.lineTo(w - 4, h - 6); ctx.lineTo(w - 20, h - 6)
                ctx.strokeStyle = root.magenta
                ctx.lineWidth = 1.6
                ctx.stroke()
            }
        }

        // faint CRT scanlines clipped to the panel
        Canvas {
            anchors.fill: parent
            opacity: 0.4
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "rgba(0,0,0,0.5)"
                ctx.lineWidth = 1
                for (let y = 3; y < height; y += 3) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 13
            spacing: 9

            // header: SYSTEM // NIGHT CITY + blink pip
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 1
                        color: root.magenta
                        SequentialAnimation on opacity {
                            running: !root.occluded; loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700 }
                            NumberAnimation { to: 1.0; duration: 700 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // types out over the first ~60% of the boot-in
                        text: "SYSTEM".substring(0, Math.round(Math.min(1, root.bootT * 1.6) * 6))
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        color: root.neon
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NIGHT CITY"
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: root.cyan
                    opacity: 0.7
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.dim; opacity: 0.5 }

            // CPU
            StatLine {
                label: "CPU"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
            }
            Meter {
                width: parent.width
                value: root.cpuPercent < 0 ? 0 : root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
            }
            Item {
                width: parent.width
                height: 22
                // per-core load bars
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: root.coreLoads
                        Item {
                            width: 5; height: 22
                            Rectangle { anchors.fill: parent; color: root.cyan; opacity: 0.07 }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, parent.height * (modelData / 100))
                                color: modelData >= 85 ? root.magenta : modelData >= 60 ? root.amber : root.cyan
                                opacity: 0.9
                                Behavior on height { NumberAnimation { duration: 250 } }
                            }
                        }
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.cpuTemp > 0 ? root.cpuTemp + "°C  ·  " : "")
                        + root.load1.toFixed(2) + "  " + root.load5.toFixed(2) + "  " + root.load15.toFixed(2)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.dim
                }
            }

            // GPU (nvidia desktops only)
            StatLine {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                label: "GPU"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
            }
            Meter {
                visible: root.hasGpu
                height: root.hasGpu ? 9 : 0
                width: parent.width
                value: root.gpuPercent < 0 ? 0 : root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
            }
            Text {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                anchors.right: parent.right
                text: root.gpuVramUsed.toFixed(1) + " / " + root.gpuVramTotal.toFixed(1) + " GB  ·  " + root.gpuTemp + "°C"
                font.family: root.mono
                font.pixelSize: 9
                color: root.dim
            }

            // MEM
            StatLine {
                label: "MEM"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
            }
            Meter {
                width: parent.width
                value: root.ramPercent < 0 ? 0 : root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
            }
            Text {
                anchors.right: parent.right
                text: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
                font.family: root.mono
                font.pixelSize: 9
                color: root.dim
            }

            // PWR (laptops only)
            StatLine {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                label: "PWR"
                glyph: root.batteryGlyph(root.batteryPercent, root.batteryCharging)
                value: root.batteryPercent
                tone: root.batteryCharging ? root.cyan
                    : root.batteryPercent <= 15 ? root.magenta
                    : root.batteryPercent <= 30 ? root.amber : root.neon
            }
            Meter {
                visible: root.hasBattery
                height: root.hasBattery ? 9 : 0
                width: parent.width
                value: root.batteryPercent < 0 ? 0 : root.batteryPercent
                tone: root.batteryCharging ? root.cyan
                    : root.batteryPercent <= 15 ? root.magenta
                    : root.batteryPercent <= 30 ? root.amber : root.neon
            }

            Rectangle { width: parent.width; height: 1; color: root.dim; opacity: 0.5 }

            // NET + UP footer
            Item {
                width: parent.width
                height: 14
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 12
                        color: root.online ? root.cyan : root.magenta
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "OFFLINE"
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.cyan : root.magenta
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓ " + root.fmtRate(root.rxRate) + "  ↑ " + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.dim
                }
            }

            // uptime moved down here to make room for the net rates
            Item {
                width: parent.width
                height: 12
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "UP " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.dim
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// NETRUNNER SYS"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.neon
                    opacity: 0.55
                }
            }
        }
    }
}
