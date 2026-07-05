import QtQuick
import Quickshell
import Quickshell.Io

// lonely-train: passenger ticket, tucked bottom-left on the dark seat.
// A night-glass ticket with a perforated stub down the left edge; each
// system gauge is a little route line — the reading is a train sliding
// between five station dots. CPU/GPU/MEM/PWR/NET off /proc + nmcli +
// nvidia-smi, sections vanish when their source is missing.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color warn:  pal.amber
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property int cpuTemp: -1
    property real load1: 0

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

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    function tone(v, warnAt, critAt) {
        return v >= critAt ? tail : v >= warnAt ? warn : amber
    }
    function pct(v) { return v < 0 ? "--" : v + "%" }

    // ── pollers ─────────────────────────────────────────────────────────────
    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true; loadProc.running = true }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
    }
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: statProc
        command: ["cat", "/proc/stat"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseStat(text) }
    }
    function parseStat(raw) {
        const line = raw.split("\n")[0]
        const f = line.trim().split(/\s+/).slice(1).map(Number)
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
            rxRate = Math.max(0, (rx - prevRx) / 1.5)
            txRate = Math.max(0, (tx - prevTx) / 1.5)
        }
        prevRx = rx; prevTx = tx
    }
    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s"
                            : Math.round(b / 1024) + " KB/s"
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
        stdout: StdioCollector { onStreamFinished: {
            const v = parseInt(text.trim())
            root.cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
        } }
    }

    Process {
        id: upProc
        command: ["cat", "/proc/uptime"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseUptime(text) }
    }
    function parseUptime(raw) {
        const s = Math.floor(parseFloat(raw.trim().split(/\s+/)[0]) || 0)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        uptimeText = String(h).padStart(3, "0") + ":" + String(m).padStart(2, "0")
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

    // ── a route-line gauge: track, five stations, the reading rides the rail ──
    component Gauge: Item {
        id: g
        property real value: 0            // 0..100
        property color toneCol: root.amber
        width: parent ? parent.width : 0
        height: 12

        Rectangle {   // track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 2
            color: root.duskA(0.25)
        }
        Rectangle {   // travelled
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, g.value / 100))
            height: 2
            color: g.toneCol
            opacity: 0.9
            Behavior on width { NumberAnimation { duration: 350 } }
        }
        Repeater {    // stations
            model: 5
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                x: index / 4 * (g.width - width)
                width: 5; height: 5; radius: 2.5
                readonly property bool passed: g.value / 100 >= index / 4
                color: passed ? g.toneCol : root.glass
                border.width: 1
                border.color: passed ? g.toneCol : root.duskA(0.5)
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }
        Rectangle {   // the little train at the reading
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, g.value / 100)) * (g.width - width)
            width: 9; height: 5; radius: 2
            color: g.toneCol
            Behavior on x { NumberAnimation { duration: 350 } }
        }
    }

    component GaugeRow: Column {
        property string label: ""
        property int value: -1
        property string detail: ""
        property color toneCol: root.amber
        width: parent ? parent.width : 0
        spacing: 4

        Item {
            width: parent.width
            height: 13
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 3
                color: root.duskA(0.85)
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.detail !== "" ? parent.parent.detail + "   " + root.pct(parent.parent.value)
                                                  : root.pct(parent.parent.value)
                font.family: root.mono
                font.pixelSize: 10
                font.weight: Font.Bold
                color: parent.parent.toneCol
            }
        }
        Gauge { value: Math.max(0, parent.value); toneCol: parent.toneCol }
    }

    // ── the ticket, bottom-left ───────────────────────────────────────────────
    Item {
        id: ticket
        width: 268
        height: col.implicitHeight + 30
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 26
        anchors.bottomMargin: 40 + 14 * (1 - root.bootT)
        opacity: root.bootT
        scale: pal.uiScale
        transformOrigin: Item.BottomLeft

        Canvas {
            id: shell
            anchors.fill: parent
            Connections {
                target: root.pal
                function onNeonChanged() { shell.requestPaint() }
                function onCyanChanged() { shell.requestPaint() }
                function onGlassChanged() { shell.requestPaint() }
            }
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height, r = 10, notch = 7, px = 30
                function col(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
                // ticket body with semicircle notches where the perforation meets the edge
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(px - notch, 0)
                ctx.arc(px, 0, notch, Math.PI, 0, true)          // top notch, cut inward
                ctx.lineTo(w - r, 0); ctx.arcTo(w, 0, w, r, r)
                ctx.lineTo(w, h - r); ctx.arcTo(w, h, w - r, h, r)
                ctx.lineTo(px + notch, h)
                ctx.arc(px, h, notch, 0, Math.PI, true)          // bottom notch
                ctx.lineTo(r, h); ctx.arcTo(0, h, 0, h - r, r)
                ctx.lineTo(0, r); ctx.arcTo(0, 0, r, 0, r)
                ctx.closePath()
                ctx.fillStyle = col(root.glass, 0.82)
                ctx.fill()
                ctx.strokeStyle = col(root.ink, 0.12)
                ctx.lineWidth = 1
                ctx.stroke()
                // the perforation
                ctx.strokeStyle = col(root.ink, 0.22)
                ctx.lineWidth = 1
                ctx.setLineDash([2, 5])
                ctx.beginPath()
                ctx.moveTo(px, notch + 3)
                ctx.lineTo(px, h - notch - 3)
                ctx.stroke()
                ctx.setLineDash([])
                // amber band along the ticket's top edge
                ctx.beginPath()
                ctx.moveTo(px + notch + 2, 1.5)
                ctx.lineTo(w - r, 1.5)
                ctx.strokeStyle = col(root.amber, 0.75)
                ctx.lineWidth = 2
                ctx.stroke()
            }
        }

        // the stub: vertical LT + dots
        Column {
            anchors.horizontalCenter: parent.left
            anchors.horizontalCenterOffset: 15
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "L"
                color: root.amberA(0.85)
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "T"
                color: root.amberA(0.85)
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Black
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: 4; radius: 2; color: root.duskA(0.6) }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: 4; radius: 2; color: root.duskA(0.35) }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 44
            anchors.rightMargin: 16
            anchors.topMargin: 15
            spacing: 9

            // header
            Item {
                width: parent.width
                height: 15
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PASSENGER"
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    font.letterSpacing: 4
                    color: root.amber
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No. 0001"
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: root.duskA(0.6)
                }
            }
            Text {
                text: "lonely train line · local service"
                font.family: root.serif
                font.pixelSize: 10
                font.italic: true
                font.letterSpacing: 1
                color: root.inkA(0.4)
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.10) }

            GaugeRow {
                label: "CPU"
                value: root.cpuPercent
                detail: (root.cpuTemp > 0 ? root.cpuTemp + "°" : "") + (root.load1 > 0 ? "  " + root.load1.toFixed(2) : "")
                toneCol: root.tone(root.cpuPercent, 60, 85)
            }
            GaugeRow {
                visible: root.hasGpu
                height: visible ? implicitHeight : 0
                label: "GPU"
                value: root.gpuPercent
                detail: root.gpuTemp > 0 ? root.gpuTemp + "°" : ""
                toneCol: root.tone(root.gpuPercent, 60, 85)
            }
            GaugeRow {
                label: "MEM"
                value: root.ramPercent
                detail: root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
                toneCol: root.tone(root.ramPercent, 70, 90)
            }
            GaugeRow {
                visible: root.hasBattery
                height: visible ? implicitHeight : 0
                label: "PWR"
                value: root.batteryPercent
                detail: root.batteryCharging ? "CHG" : ""
                toneCol: root.batteryCharging ? root.dusk
                    : root.batteryPercent <= 15 ? root.tail
                    : root.batteryPercent <= 30 ? root.warn : root.amber
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.10) }

            // NET + REEL footer
            Item {
                width: parent.width
                height: 13
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.online ? root.duskA(0.9) : root.tail
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "OFFLINE"
                        font.family: root.mono
                        font.pixelSize: 9
                        color: root.online ? root.duskA(0.9) : root.tail
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 8
                    color: root.inkA(0.35)
                }
            }
            Item {
                width: parent.width
                height: 11
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: root.tail
                        opacity: 0.85
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REEL " + root.uptimeText
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        color: root.inkA(0.4)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "valid one ride only"
                    font.family: root.serif
                    font.pixelSize: 9
                    font.italic: true
                    color: root.inkA(0.28)
                }
            }
        }
    }
}
