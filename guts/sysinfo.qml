import QtQuick
import Quickshell
import Quickshell.Io

// guts: system readout as manga margin notes, pinned bottom-right over the
// dark figure — so it sits on its own torn scrap of paper. An imperfect
// double ink rule brush-draws itself around the panel on load, a screentone
// dot field shades the corner, and every meter is a row of halftone dots
// that fill like inked-in tone (hot values bleed red). CPU/MEM/NET from
// /proc + nmcli, GPU only if nvidia-smi exists, battery only on laptops.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color dried: pal.amber
    readonly property color halft: pal.dim
    readonly property color paper: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // ── live state (moon-style plumbing, guts-style face) ────────────────────
    property int cpuPercent: -1
    property real load1: 0
    property int cpuTemp: -1
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
    property real rxRate: 0
    property real txRate: 0
    property real prevRx: -1
    property real prevTx: -1
    property real prevTotal: 0
    property real prevIdle: 0

    function tone(v, warn, crit) {
        return v >= crit ? fresh : v >= warn ? dried : ink
    }
    function pct(v) { return v < 0 ? "—" : v + "%" }
    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + "M" : Math.round(b / 1024) + "K"
    }

    // ── pollers ──────────────────────────────────────────────────────────────
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
    }
    Timer {
        interval: 12000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -1 /proc/stat; cat /proc/loadavg"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseStat(text) }
    }
    function parseStat(raw) {
        const lines = raw.trim().split("\n")
        const f = lines[0].trim().split(/\s+/).slice(1).map(Number)
        if (f.length >= 5) {
            const idle = f[3] + f[4]
            const total = f.reduce((a, b) => a + b, 0)
            const dT = total - prevTotal, dI = idle - prevIdle
            if (prevTotal > 0 && dT > 0) cpuPercent = Math.round(100 * (dT - dI) / dT)
            prevTotal = total; prevIdle = idle
        }
        if (lines[1]) load1 = parseFloat(lines[1].trim().split(/\s+/)[0]) || 0
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

    Process {
        id: gpuProc
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || true"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseGpu(text) }
    }
    function parseGpu(raw) {
        const line = raw.trim().split("\n")[0] || ""
        const f = line.split(",").map(s => parseFloat(s))
        if (f.length < 2 || isNaN(f[0])) { hasGpu = false; return }
        hasGpu = true
        gpuPercent = Math.round(f[0])
        gpuTemp = Math.round(f[1])
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

    // ── a halftone meter: dots ink themselves in, hot dots bleed red ─────────
    component ToneBar: Row {
        id: bar
        property real value: 0            // 0..100
        property color toneCol: root.ink
        property int cells: 20
        spacing: Math.round(3 * root.ui)
        Repeater {
            model: bar.cells
            Rectangle {
                required property int index
                readonly property bool lit: index < Math.round(bar.value / 100 * bar.cells)
                width: Math.round(4.5 * root.ui); height: width
                radius: width / 2
                // unlit dots are the faint screentone; lit ones are inked in
                color: lit ? bar.toneCol : root.inkA(0.13)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }
    }

    component NoteRow: Item {
        property string label: ""
        property string kanji: ""
        property string value: ""
        property color toneCol: root.ink
        width: parent ? parent.width : 0
        implicitHeight: Math.round(17 * root.ui)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(7 * root.ui)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(9 * root.ui); height: Math.round(2 * root.ui)
                rotation: -32
                color: root.blood
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(12 * root.ui)
                font.letterSpacing: 2
                color: root.inkA(0.72)
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: value
            font.family: root.mono
            font.weight: Font.Bold
            font.pixelSize: Math.round(13 * root.ui)
            color: toneCol
        }
    }

    // ── the margin-note scrap, bottom-right ──────────────────────────────────
    Item {
        id: panel
        width: Math.round(236 * root.ui)
        height: col.implicitHeight + Math.round(34 * root.ui)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.round(26 * root.ui)
        anchors.bottomMargin: Math.round(26 * root.ui)

        // the border brush-draws itself on load; contents fade in after
        property real borderT: 0
        NumberAnimation on borderT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.InOutQuad }

        // torn paper scrap
        Canvas {
            id: paperCv
            anchors.fill: parent
            Connections {
                target: root.pal
                function onGlassChanged() { paperCv.requestPaint() }
                function onTextChanged() { paperCv.requestPaint() }
            }
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                // slightly irregular paper edge — a scrap, not a card
                ctx.beginPath()
                ctx.moveTo(4, 2)
                ctx.lineTo(w * 0.4, 0); ctx.lineTo(w - 2, 3)
                ctx.lineTo(w, h * 0.5); ctx.lineTo(w - 3, h - 2)
                ctx.lineTo(w * 0.55, h); ctx.lineTo(3, h - 3)
                ctx.lineTo(0, h * 0.45)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.95)
                ctx.fill()
                // screentone shading in the top-right corner
                ctx.fillStyle = root.inkA(0.14)
                for (let gy = 6; gy < h * 0.3; gy += 7) {
                    for (let gx = w - 6; gx > w * 0.6; gx -= 7) {
                        const dd = Math.hypot(w - gx, gy) / (w * 0.42)
                        if (dd > 1) continue
                        ctx.beginPath()
                        ctx.arc(gx + (gy % 14 === 6 ? 3 : 0), gy, 1.6 * (1 - dd), 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }

        // imperfect double rule, drawn in like a brush tracing the frame
        Canvas {
            id: frameCv
            anchors.fill: parent
            Connections {
                target: root.pal
                function onTextChanged() { frameCv.requestPaint() }
            }
            Connections {
                target: panel
                function onBorderTChanged() { frameCv.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                const per = 2 * (w + h)
                let budget = per * panel.borderT
                ctx.strokeStyle = root.inkA(0.88)
                ctx.lineWidth = 2
                function seg(x0, y0, x1, y1) {
                    if (budget <= 0) return
                    const len = Math.hypot(x1 - x0, y1 - y0)
                    const f = Math.min(1, budget / len)
                    budget -= len
                    const xe = x0 + (x1 - x0) * f, ye = y0 + (y1 - y0) * f
                    ctx.beginPath()
                    ctx.moveTo(x0, y0)
                    const steps = 12
                    for (let i = 1; i <= steps; i++) {
                        const t = i / steps
                        const wob = Math.sin(t * 8 + x0 * 0.1 + y0 * 0.1) * 0.8
                        ctx.lineTo(x0 + (xe - x0) * t + (y0 === y1 ? 0 : wob),
                                   y0 + (ye - y0) * t + (y0 === y1 ? wob : 0))
                    }
                    ctx.stroke()
                }
                seg(2, 2, w - 2, 2)
                seg(w - 2, 2, w - 2, h - 2)
                seg(w - 2, h - 2, 2, h - 2)
                seg(2, h - 2, 2, 2)
                // inner hairline, offset — the double manga rule
                ctx.lineWidth = 1
                ctx.strokeStyle = root.inkA(0.30 * panel.borderT)
                ctx.strokeRect(6.5, 6.5, w - 13, h - 13)
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(17 * root.ui)
            spacing: Math.round(7 * root.ui)
            opacity: Math.max(0, (panel.borderT - 0.5) * 2)

            // header
            Item {
                width: parent.width
                height: Math.round(16 * root.ui)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(7 * root.ui)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(12 * root.ui); height: Math.round(2.5 * root.ui)
                        rotation: -32
                        color: root.blood
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "MARGIN NOTES"
                        font.family: root.serif
                        font.pixelSize: Math.round(12 * root.ui)
                        font.letterSpacing: 4
                        font.weight: Font.Bold
                        color: root.ink
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.35) }

            // CPU
            NoteRow {
                label: "cpu"; kanji: "力"
                value: root.pct(root.cpuPercent)
                toneCol: root.tone(root.cpuPercent, 60, 85)
            }
            ToneBar {
                value: root.cpuPercent < 0 ? 0 : root.cpuPercent
                toneCol: root.tone(root.cpuPercent, 60, 85)
            }
            Text {
                anchors.right: parent.right
                text: (root.cpuTemp > 0 ? root.cpuTemp + "°c · " : "") + "load " + root.load1.toFixed(2)
                font.family: root.mono
                font.pixelSize: Math.round(9 * root.ui)
                color: root.inkA(0.45)
            }

            // GPU (nvidia only)
            NoteRow {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                label: "gpu"; kanji: "獣"
                value: root.pct(root.gpuPercent) + (root.gpuTemp > 0 ? " · " + root.gpuTemp + "°c" : "")
                toneCol: root.tone(root.gpuPercent, 60, 85)
            }
            ToneBar {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                value: root.gpuPercent < 0 ? 0 : root.gpuPercent
                toneCol: root.tone(root.gpuPercent, 60, 85)
            }

            // MEM
            NoteRow {
                label: "mem"; kanji: "器"
                value: root.pct(root.ramPercent)
                toneCol: root.tone(root.ramPercent, 70, 90)
            }
            ToneBar {
                value: root.ramPercent < 0 ? 0 : root.ramPercent
                toneCol: root.tone(root.ramPercent, 70, 90)
            }
            Text {
                anchors.right: parent.right
                text: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " gb"
                font.family: root.mono
                font.pixelSize: Math.round(9 * root.ui)
                color: root.inkA(0.45)
            }

            // battery (laptops)
            NoteRow {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                label: root.batteryCharging ? "pwr +" : "pwr"; kanji: "灯"
                value: root.pct(root.batteryPercent)
                toneCol: root.batteryCharging ? root.ink
                    : root.batteryPercent <= 15 ? root.fresh
                    : root.batteryPercent <= 30 ? root.dried : root.ink
            }
            ToneBar {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                value: root.batteryPercent < 0 ? 0 : root.batteryPercent
                toneCol: root.batteryCharging ? root.ink
                    : root.batteryPercent <= 15 ? root.fresh
                    : root.batteryPercent <= 30 ? root.dried : root.ink
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.35) }

            // NET + uptime footer
            Item {
                width: parent.width
                height: Math.round(14 * root.ui)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(6 * root.ui)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(root.online
                            ? (root.connType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
                        font.family: root.icon
                        font.pixelSize: Math.round(11 * root.ui)
                        color: root.online ? root.inkA(0.7) : root.fresh
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "severed"
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: Math.round(11 * root.ui)
                        color: root.online ? root.inkA(0.7) : root.fresh
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: Math.round(9 * root.ui)
                    color: root.inkA(0.45)
                }
            }
            Item {
                width: parent.width
                height: Math.round(12 * root.ui)
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "awake " + root.uptimeText
                    font.family: root.serif
                    font.italic: true
                    font.pixelSize: Math.round(10 * root.ui)
                    color: root.inkA(0.45)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// the brand of sacrifice"
                    font.family: root.serif
                    font.pixelSize: Math.round(9 * root.ui)
                    color: Qt.rgba(root.blood.r, root.blood.g, root.blood.b, 0.7)
                }
            }
        }
    }
}
