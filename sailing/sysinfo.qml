import QtQuick
import Quickshell
import Quickshell.Io

// sailing: the wheelhouse — instrument cluster for the "THROUGH SILENCE"
// wallpaper. A slate cabin panel pinned bottom-right under the canopy shadow,
// carrying a row of porthole-shaped needle gauges: ENG = CPU, HOLD = MEM,
// GPU (nvidia only), FUEL = battery. Each gauge is a brass-rimmed dial with
// a red zone at the top of the scale; needles ease to each reading. Below,
// the RADIO strip: shore connection + up/down rates, and time at sea.
// Self-contained: /proc, nmcli, nvidia-smi. Polls only — idle-cheap.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color buoy:  pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color alarm: pal.magenta
    readonly property color lamp:  pal.amber
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function buoyA(a)  { return Qt.rgba(buoy.r, buoy.g, buoy.b, a) }
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    // ── hover reveal ─────────────────────────────────────────────────────────
    // The bar's wheelhouse dial writes "1"/"0" to this flag file while hovered;
    // the card stays off the desktop until the officer consults the instruments.
    property bool hoverShown: false
    property bool pinShown: false
    property real showT: (hoverShown || pinShown) ? 1 : 0
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
    // pinned keeps the card on deck without hovering the dial
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

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property int cpuTemp: -1
    property int ramPercent: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property bool hasGpu: false
    property int gpuPercent: -1
    property int gpuTemp: -1
    property bool hasBattery: false
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool online: false
    property string connName: ""
    property string uptimeText: "—"
    property real rxRate: 0
    property real txRate: 0
    property real prevRx: -1
    property real prevTx: -1
    property real prevTotal: 0
    property real prevIdle: 0

    // boot-in: the panel surfaces; needles then sweep up with the first polls
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // ── pollers ─────────────────────────────────────────────────────────────
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
    }
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
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
        uptimeText = d > 0 ? `${d}D ${h}H` : h > 0 ? `${h}H ${m}M` : `${m}M`
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connName = ""; return }
                root.online = true
                root.connName = line.slice(0, line.lastIndexOf(":"))
            }
        }
    }

    // ── a porthole gauge: brass rim, ticks, red zone, easing needle ─────────
    component Gauge: Item {
        id: g
        property string label: ""
        property string sub: ""
        property int value: -1          // 0..100, -1 = no reading yet
        property bool charging: false   // FUEL only: tints the needle lavender

        // needle eases toward each new reading
        property real shown: 0
        Behavior on shown { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        onValueChanged: shown = Math.max(0, value)
        onShownChanged: face.requestPaint()

        width: 64
        height: 88

        Canvas {
            id: face
            width: 64; height: 64
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            Connections {
                target: root.pal
                function onNeonChanged() { face.requestPaint() }
                function onAmberChanged() { face.requestPaint() }
                function onDimChanged() { face.requestPaint() }
                function onTextChanged() { face.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2, r = 29
                const a0 = Math.PI * 0.75, a1 = Math.PI * 2.25   // 270° sweep, gap at the bottom

                // glass face + brass rim (a porthole)
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.fillStyle = root.glassA(0.66); ctx.fill()
                ctx.lineWidth = 1.6; ctx.strokeStyle = root.lampA(0.85); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx, cy, r - 3, 0, Math.PI * 2)
                ctx.lineWidth = 1; ctx.strokeStyle = root.slateA(0.45); ctx.stroke()

                // red zone: the top fifth of the scale
                ctx.beginPath(); ctx.arc(cx, cy, r - 6, a0 + (a1 - a0) * 0.8, a1)
                ctx.lineWidth = 2.5; ctx.strokeStyle = root.buoyA(0.8); ctx.stroke()

                // ticks — major every quarter
                for (let i = 0; i <= 12; i++) {
                    const t = i / 12
                    const a = a0 + (a1 - a0) * t
                    const major = i % 3 === 0
                    const r1 = r - 6, r2 = r1 - (major ? 5 : 3)
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                    ctx.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2)
                    ctx.lineWidth = major ? 1.4 : 1
                    ctx.strokeStyle = major ? root.paleA(0.6) : root.slateA(0.7)
                    ctx.stroke()
                }

                // the needle
                if (g.value >= 0) {
                    const t = Math.min(1, g.shown / 100)
                    const a = a0 + (a1 - a0) * t
                    const col = g.charging ? root.dusk
                              : t >= 0.88 ? root.alarm
                              : t >= 0.7 ? root.lamp : root.pale
                    ctx.beginPath()
                    ctx.moveTo(cx - Math.cos(a) * 4, cy - Math.sin(a) * 4)
                    ctx.lineTo(cx + Math.cos(a) * (r - 9), cy + Math.sin(a) * (r - 9))
                    ctx.lineWidth = 1.7
                    ctx.strokeStyle = col
                    ctx.stroke()
                }

                // brass hub
                ctx.beginPath(); ctx.arc(cx, cy, 2.4, 0, Math.PI * 2)
                ctx.fillStyle = root.lampA(0.95); ctx.fill()
            }
        }

        // the reading, set into the bottom gap of the dial
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 48
            text: g.value < 0 ? "--" : g.value + "%"
            color: root.paleA(0.9)
            font.family: root.mono
            font.pixelSize: 9
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 64
            text: g.label
            color: root.duskA(0.9)
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 3
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 77
            text: g.sub
            color: root.slateA(1)
            font.family: root.mono
            font.pixelSize: 8
            font.letterSpacing: 1
        }
    }

    // ── the panel, pinned bottom-right above the railing bar ────────────────
    Rectangle {
        id: panel
        width: gaugeRow.width + 40
        height: 158
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 26
        anchors.bottomMargin: 70 - 12 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01

        scale: pal.uiScale
        transformOrigin: Item.BottomRight

        radius: 10
        color: root.glassA(0.78)
        border.width: 1
        border.color: root.lampA(0.4)

        // header: lamp dot + INSTRUMENTS, deck tag right
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 14

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: root.lamp
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WHEELHOUSE"
                    color: root.duskA(0.95)
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 4
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "DECK B"
                color: root.slateA(1)
                font.family: root.mono
                font.pixelSize: 8
                font.letterSpacing: 2
            }
        }

        // railing rule under the header
        Item {
            id: headRule
            anchors.top: header.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 8
            Rectangle { y: 1; width: parent.width; height: 1; color: root.paleA(0.28) }
            Rectangle { y: 5; width: parent.width; height: 1; color: root.slateA(0.55) }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: index === 2 ? parent.width - 2 : Math.round(parent.width * index / 2)
                    width: 2; height: 7
                    color: root.paleA(0.5)
                }
            }
        }

        // the dials
        Row {
            id: gaugeRow
            anchors.top: headRule.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Gauge {
                label: "ENG"
                value: root.cpuPercent
                sub: root.cpuTemp > 0 ? root.cpuTemp + "°C" : ""
            }
            Gauge {
                label: "HOLD"
                value: root.ramPercent
                sub: root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + " GB"
            }
            Gauge {
                visible: root.hasGpu
                width: root.hasGpu ? 64 : 0
                label: "GPU"
                value: root.gpuPercent
                sub: root.gpuTemp > 0 ? root.gpuTemp + "°C" : ""
            }
            Gauge {
                visible: root.hasBattery
                width: root.hasBattery ? 64 : 0
                label: "FUEL"
                value: root.batteryPercent
                charging: root.batteryCharging
                sub: root.batteryCharging ? "TAKING ON" : "RESERVE"
            }
        }

        // RADIO strip: shore link + rates left, time at sea right
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 9
            height: 12

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RADIO"
                    color: root.online ? root.duskA(0.8) : root.alarm
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.online
                        ? "↓ " + root.fmtRate(root.rxRate) + "  ↑ " + root.fmtRate(root.txRate)
                        : "NO SIGNAL"
                    color: root.online ? root.slateA(1) : root.alarm
                    font.family: root.mono
                    font.pixelSize: 8
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "AT SEA " + root.uptimeText
                color: root.slateA(1)
                font.family: root.mono
                font.pixelSize: 8
                font.letterSpacing: 1
            }
        }
    }
}
