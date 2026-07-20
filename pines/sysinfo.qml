import QtQuick
import Quickshell
import Quickshell.Io

// pines: the instrument shelf. Hover the little barograph in the sill (or
// pin with Super+.) and the station's readout board condenses down out of
// the fog at the top right, swaying once on its hook before it settles —
// hand instruments, not telemetry: WIND is the CPU on a damped needle gauge
// (needles overshoot and settle, never snap), PRESSURE is memory, GENERATOR
// the GPU, LAMP OIL the battery vial, W/T LINK the wireless set. The foot of
// the board logs the watch. Sections with no source (no nvidia-smi, no
// battery) never appear. Reads /proc + nmcli itself; polls only while
// revealed; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color lamp: pal.neon
    readonly property color fogSilver: pal.cyan
    readonly property color emberCol: pal.magenta
    readonly property color brass: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function lampA(a)   { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function silverA(a) { return Qt.rgba(fogSilver.r, fogSilver.g, fogSilver.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property int cpuTemp: -1
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

    function tone(v, w, c) { return v >= c ? emberCol : v >= w ? brass : lamp }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // hover reveal — the sill's barograph trigger writes "1"/"0" here
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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

    // ── pollers — only while the board is actually down ─────────────────────
    Timer {
        interval: 2000; running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 5000; running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
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

    // ── an instrument row: serif label, damped needle gauge, mono readout ──
    component GaugeRow: Item {
        id: row
        property string label: "WIND"
        property int value: -1        // 0..100; -1 leaves the needle at rest
        property color tone: root.lamp
        property string readout: ""
        width: parent ? parent.width : 0
        height: 34

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.serif
            font.pixelSize: 12
            font.letterSpacing: 3
            color: root.inkA(0.92)
        }

        // the gauge: a half-arc scale and a needle that overshoots and damps
        Item {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            width: 56; height: 26

            Canvas {
                id: scaleArc
                anchors.fill: parent
                Component.onCompleted: requestPaint()
                Connections {
                    target: root.pal
                    function onDimChanged() { scaleArc.requestPaint() }
                    function onCyanChanged() { scaleArc.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height - 2, r = height - 5
                    ctx.strokeStyle = String(root.slateA(0.9))
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, Math.PI * 1.08, Math.PI * 1.92)
                    ctx.stroke()
                    // scale ticks
                    for (let i = 0; i <= 6; i++) {
                        const a = Math.PI * (1.08 + 0.84 * i / 6)
                        const r0 = i % 3 === 0 ? r - 5 : r - 3
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                        ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                        ctx.strokeStyle = String(root.silverA(i % 3 === 0 ? 0.6 : 0.4))
                        ctx.stroke()
                    }
                }
            }
            // the needle — a hairline on a brass pivot, damped by easing
            Rectangle {
                id: needle
                x: dial.width / 2 - 0.7
                y: 3
                width: 1.4
                height: dial.height - 6
                color: row.value >= 0 ? row.tone : root.slateA(0.9)
                antialiasing: true
                transform: Rotation {
                    origin.x: 0.7
                    origin.y: needle.height
                    angle: -76 + 152 * Math.max(0, Math.min(100, row.value < 0 ? 0 : row.value)) / 100
                    Behavior on angle { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                }
            }
            Rectangle {   // the pivot screw
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.height - 4
                width: 4; height: 4; radius: 2
                color: root.brass
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 11
            color: row.value >= 0 ? row.tone : root.silverA(0.7)
        }
    }

    // ── the board, condensing down at the top right ─────────────────────────
    Item {
        id: board
        width: 308
        height: face.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 28
        anchors.topMargin: 50 + 12 * root.showT
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale * (1.03 - 0.03 * root.showT)   // sharpens as it condenses
        transformOrigin: Item.TopRight

        // the hook sway: the board takes its weight, rocks, hangs still
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -2.2; to: 1.1; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.1; to: -0.5; duration: 430; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.5; to: 0; duration: 370; easing.type: Easing.OutSine }
        }

        Rectangle {
            id: face
            width: parent.width
            height: col.implicitHeight + 32
            radius: 4
            color: root.glassA(0.88)
            border.width: 1
            border.color: root.silverA(0.35)
        }
        // the lamp's warmth falling on the board's head
        Rectangle {
            width: parent.width - 2; x: 1; y: 1
            height: 42
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.lampA(0.08) }
                GradientStop { position: 1.0; color: root.lampA(0.0) }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 15
            spacing: 3

            // header
            Item {
                width: parent.width
                height: 20
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        id: headLamp
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: root.lamp
                        SequentialAnimation on opacity {
                            running: root.shown && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INSTRUMENT SHELF"
                        font.family: root.serif
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        color: root.lampA(0.95)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PINES-9"
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: root.silverA(0.7)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.slateA(0.6) }

            GaugeRow {
                label: "WIND"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            GaugeRow {
                label: "PRESSURE"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            GaugeRow {
                visible: root.hasGpu
                height: root.hasGpu ? 34 : 0
                label: "GENERATOR"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }

            // LAMP OIL — the battery vial (laptops only)
            Item {
                visible: root.hasBattery
                width: parent.width
                height: root.hasBattery ? 26 : 0
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "LAMP OIL"
                    font.family: root.serif
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    color: root.inkA(0.92)
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56; height: 10
                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.slateA(1)
                    }
                    Rectangle {
                        x: 2; y: 2
                        width: Math.max(0, (parent.width - 4) * Math.max(0, root.batteryPercent) / 100)
                        height: parent.height - 4
                        radius: 1
                        color: root.batteryCharging ? root.fogSilver
                             : root.batteryPercent <= 15 ? root.emberCol
                             : root.batteryPercent <= 30 ? root.brass
                             : root.lampA(0.9)
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.batteryCharging ? "FILLING " : "") + root.batteryPercent + "%"
                    font.family: root.mono
                    font.pixelSize: 11
                    color: root.batteryCharging ? root.fogSilver
                         : root.batteryPercent <= 15 ? root.emberCol : root.inkA(0.9)
                }
            }

            // W/T LINK — text only: the set either hears the valley or it doesn't
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "W/T LINK"
                        font.family: root.serif
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        color: root.inkA(0.92)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: root.online ? root.silverA(0.95) : root.emberCol
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "NO CARRIER"
                        textFormat: Text.PlainText
                        width: Math.min(implicitWidth, 92)
                        elide: Text.ElideRight
                        font.family: root.mono
                        font.pixelSize: 11
                        color: root.online ? root.inkA(0.9) : root.emberCol
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 10
                    color: root.silverA(0.7)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.slateA(0.6) }

            // the watch log foot
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ON WATCH " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: root.inkA(0.8)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▵ STANDING WATCH"
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: root.lampA(0.7)
                }
            }
        }
    }
}
