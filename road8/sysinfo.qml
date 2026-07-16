import QtQuick
import Quickshell
import Quickshell.Io

// road8: the instrument cluster. Hover the CHECK lamp in the bar (or pin with
// Super+.) and the dash drops down from behind the road overhead, settling on
// its suspension — a bob and a pitch, the way a parked car takes your weight.
// Every subsystem is a gauge with an OBD-style code: P01 RPM is the CPU,
// P02 FUEL is memory, P03 TURBO the GPU, P04 BATT the battery, P05 RADIO the
// network. Meters are rows of hard square pixels that fill amber, run sodium
// orange, then taillight red. The odometer at the foot counts uptime.
// Sections with no source (no nvidia-smi, no battery) never light. Reads
// /proc + nmcli itself; polls only while revealed; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color alert: pal.magenta
    readonly property color warm: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property int cpuTemp: -1
    property real load1: 0

    property int ramPercent: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    property bool hasGpu: false
    property int gpuPercent: -1
    property int gpuTemp: -1

    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

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

    function tone(v, w, c) { return v >= c ? alert : v >= w ? warm : amber }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // hover reveal — the bar's CHECK lamp writes "1"/"0" here while hovered;
    // the cluster stays dark until the driver glances down
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) settle.restart()
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
    // Super+. pin — the shell writes "1"/"0" here (`qs ipc call sysinfo toggle`)
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
    // poll only while the cluster is actually lit (reveal refreshes instantly)
    Timer {
        interval: 2000; running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 5000; running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true; loadProc.running = true }
    }
    Timer {
        interval: 10000; running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
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
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                root.cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "[ -d /sys/module/nvidia ] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || true"]
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
        uptimeText = d > 0 ? `${d}D ${h}H ${m}M` : h > 0 ? `${h}H ${m}M` : `${m}M`
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

    // ── a gauge row: OBD code, label, pixel meter, readout ──────────────────
    component GaugeRow: Item {
        id: row
        property string code: "P01"
        property string label: "RPM"
        property int value: -1        // 0..100, -1 leaves the meter dark
        property color tone: root.amber
        property string readout: ""
        width: parent ? parent.width : 0
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.code
            font.family: root.mono
            font.pixelSize: 9
            font.weight: Font.Bold
            color: root.slateA(1.0)
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 2
            color: root.inkA(0.85)
        }

        // the meter: 12 hard square pixels — quantized, no half-light
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 82
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 100 * 12)
                    width: 8; height: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: lit ? row.tone : "transparent"
                    border.width: 1
                    border.color: lit ? row.tone : root.slateA(0.5)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tone : root.slateA(1.0)
        }
    }

    // ── the cluster, dropping from behind the road overhead ─────────────────
    Item {
        id: cluster
        width: 316
        height: face.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 26
        anchors.topMargin: 48 + 14 * root.showT
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // the suspension: the dash takes your weight, bobs, and settles level
        SequentialAnimation on rotation {
            id: settle
            running: false
            NumberAnimation { from: -1.8; to: 0.9; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: -0.4; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.4; to: 0; duration: 360; easing.type: Easing.OutSine }
        }

        // pixel-cut face — the same stepped corners as everything on this road
        Canvas {
            id: face
            width: parent.width
            height: col.implicitHeight + 30
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { face.requestPaint() }
                function onGlassChanged() { face.requestPaint() }
                function onDimChanged() { face.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const w = width, h = height, s = 5
                ctx.beginPath()
                ctx.moveTo(s, 0.5)
                ctx.lineTo(w - s, 0.5)
                ctx.lineTo(w - s, s); ctx.lineTo(w - 0.5, s)
                ctx.lineTo(w - 0.5, h - s); ctx.lineTo(w - s, h - s)
                ctx.lineTo(w - s, h - 0.5); ctx.lineTo(s, h - 0.5)
                ctx.lineTo(s, h - s); ctx.lineTo(0.5, h - s)
                ctx.lineTo(0.5, s); ctx.lineTo(s, s)
                ctx.closePath()
                ctx.fillStyle = String(root.glassA(0.88))
                ctx.fill()
                ctx.strokeStyle = String(root.amberA(0.45))
                ctx.lineWidth = 1
                ctx.stroke()
                // dash top glow, like the cluster's own backlight
                const g = ctx.createLinearGradient(0, 0, 0, 44)
                g.addColorStop(0, String(root.amberA(0.10)))
                g.addColorStop(1, String(root.amberA(0)))
                ctx.fillStyle = g
                ctx.fillRect(2, 1, w - 4, 44)
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 14
            spacing: 4

            // header: the CHECK lamp, hard-blinking while the cluster is up
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        id: checkLamp
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7
                        property bool tick: true
                        color: tick ? root.amber : root.amberA(0.25)
                        Timer {
                            interval: 800; repeat: true
                            running: root.shown && !root.occluded
                            onTriggered: checkLamp.tick = !checkLamp.tick
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "8BIT2 · DASH"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        color: root.amber
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SELF-TEST"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.slateA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.slateA(0.6) }

            GaugeRow {
                code: "P01"; label: "RPM"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            GaugeRow {
                code: "P02"; label: "FUEL"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            GaugeRow {
                visible: root.hasGpu
                height: root.hasGpu ? 28 : 0
                code: "P03"; label: "TURBO"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            GaugeRow {
                visible: root.hasBattery
                height: root.hasBattery ? 28 : 0
                code: "P04"; label: "BATT"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.starlight
                    : root.batteryPercent <= 15 ? root.alert
                    : root.batteryPercent <= 30 ? root.warm : root.amber
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // P05 RADIO is text-only: connection left, rates right
            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "P05"
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: root.slateA(1.0)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.online ? root.starlight : root.alert
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "OFFLINE"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.inkA(0.8) : root.alert
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.slateA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.slateA(0.6) }

            // the odometer: uptime, and whose dash this is
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5; height: 7
                            color: "transparent"
                            border.width: 1
                            border.color: root.amberA(index === 0 ? 0.9 : index === 1 ? 0.5 : 0.28)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ODO " + root.uptimeText
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: root.inkA(0.6)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▪ BEFORE THE ROAD"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.amberA(0.5)
                }
            }
        }
    }
}
