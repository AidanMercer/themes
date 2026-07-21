import QtQuick
import Quickshell
import Quickshell.Io

// downpour: the wiped patch. Lean on the bar's breath mark (or pin with
// Super+.) and a hand wipes a clear patch in the fogged glass, upper right —
// the readings were out there the whole time, you just couldn't see through.
// The patch reveals with the wipe's own gesture: contents surface behind a
// left-to-right clear, the panel settling with the hand's follow-through.
// Every reading is a water level in a thin vial; condensation gathers as
// beads along the patch's lower rim. Plain lowercase labels: cpu, memory,
// gpu, charge, net. Sections with no source (no nvidia-smi, no battery)
// never appear. Reads /proc + nmcli itself; polls only while revealed;
// click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color paneLight: pal.neon
    readonly property color skinLight: pal.cyan
    readonly property color warmth: pal.magenta
    readonly property color warn: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function paneA(a)  { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
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

    function tone(v, w, c) { return v >= c ? warmth : v >= w ? warn : paneLight }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // hover reveal — the bar's breath mark writes "1"/"0" here while hovered
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) { settle.restart(); wipeAnim.restart() }
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 380; easing.type: Easing.InOutSine } }
    property real wipeT: 1
    NumberAnimation { id: wipeAnim; target: root; property: "wipeT"; from: 0.1; to: 1; duration: 620; easing.type: Easing.InOutSine }

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

    // ── pollers — only while the patch is actually wiped ────────────────────
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
        uptimeText = d > 0 ? `${d}d ${h}h ${m}m` : h > 0 ? `${h}h ${m}m` : `${m}m`
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

    // ── one reading: a plain label, a vial's water level, the number ────────
    component VialRow: Item {
        id: row
        property string label: ""
        property int value: -1        // 0..100, -1 keeps the vial dry
        property color tone: root.paneLight
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.serif
            font.italic: true
            font.pixelSize: 13
            color: root.inkA(0.72)
        }
        // the vial: a thin lying-down sliver of glass, water creeping along it
        Item {
            anchors.left: parent.left
            anchors.leftMargin: 88
            anchors.verticalCenter: parent.verticalCenter
            width: 116; height: 8
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: root.slateA(0.8)
            }
            Rectangle {
                x: 1.5
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, (parent.width - 3) * Math.max(0, row.value) / 100)
                height: 5
                radius: 2.5
                color: Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.75)
                Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.InOutSine } }
                // the meniscus bead at the water's edge
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width - 2
                    width: 4; height: 6.5
                    radius: 2
                    color: Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.95)
                    visible: row.value > 1
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 11
            color: row.value >= 0 ? Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.95) : root.slateA(1.0)
        }
    }

    // ── the patch, wiped into the upper-right glass ─────────────────────────
    Item {
        id: patch
        width: 330
        height: face.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 24
        anchors.topMargin: 46 + 10 * root.showT
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // the hand's follow-through: the patch takes the wipe and settles
        SequentialAnimation on rotation {
            id: settle
            running: false
            NumberAnimation { from: -1.6; to: 0.8; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.8; to: -0.3; duration: 460; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.3; to: 0; duration: 400; easing.type: Easing.OutSine }
        }

        // the wiped blob: irregular corners, a paler interior (the clearer
        // view), condensation beads gathered along its lower rim
        Canvas {
            id: face
            width: parent.width
            height: col.implicitHeight + 34
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
                const w = width, h = height
                // per-corner wobbled radii — a wipe never leaves a neat rectangle
                const r = [22, 30, 26, 34].map((v, i) => v * (0.8 + 0.5 * root.rnd(i * 19 + 3)))
                ctx.beginPath()
                ctx.moveTo(r[0], 1)
                ctx.lineTo(w - r[1], 1); ctx.quadraticCurveTo(w - 1, 1, w - 1, r[1])
                ctx.lineTo(w - 1, h - r[2]); ctx.quadraticCurveTo(w - 1, h - 1, w - r[2], h - 1)
                ctx.lineTo(r[3], h - 1); ctx.quadraticCurveTo(1, h - 1, 1, h - r[3])
                ctx.lineTo(1, r[0]); ctx.quadraticCurveTo(1, 1, r[0], 1)
                ctx.closePath()
                ctx.fillStyle = String(root.glassA(0.78))
                ctx.fill()
                ctx.strokeStyle = String(root.inkA(0.14))
                ctx.lineWidth = 1.4
                ctx.stroke()
                // the clearer view: a faint paleness pooling in the middle
                const g = ctx.createRadialGradient(w * 0.5, h * 0.42, 0, w * 0.5, h * 0.42, w * 0.55)
                g.addColorStop(0, String(root.inkA(0.045)))
                g.addColorStop(1, String(root.inkA(0)))
                ctx.fillStyle = g
                ctx.fill()
                // beads gathered along the lower rim — where the wipe pushed
                // the water
                for (let i = 0; i < 6; i++) {
                    const bx = w * (0.10 + 0.15 * i + 0.05 * root.rnd(i * 43 + 11))
                    const bs = 2.6 + 2.4 * root.rnd(i * 7 + 2)
                    ctx.beginPath()
                    ctx.ellipse(bx, h - 3 - bs, bs, bs * 1.25)
                    ctx.fillStyle = String(root.paneA(0.42))
                    ctx.fill()
                }
            }
        }

        // contents surface behind the wipe's leading edge
        Item {
            anchors.fill: parent
            clip: true
            Item {
                width: patch.width * root.wipeT
                height: parent.height
                clip: true

                Column {
                    id: col
                    width: patch.width - 40
                    x: 20
                    y: 16
                    spacing: 5

                    // header: a bead that breathes while the patch is clear
                    Item {
                        width: parent.width
                        height: 22
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 9
                            Rectangle {
                                id: headBead
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7; height: 8.5
                                radius: 4
                                color: root.paneA(0.8)
                                Rectangle { x: 1.4; y: 1.6; width: 2; height: 2; radius: 1; color: root.inkA(0.85) }
                                SequentialAnimation on scale {
                                    running: root.shown && !root.occluded
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.2; duration: 2400; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.9; duration: 2400; easing.type: Easing.InOutSine }
                                    onStopped: headBead.scale = 1
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "system"
                                font.family: root.serif
                                font.italic: true
                                font.pixelSize: 14
                                color: root.inkA(0.85)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.slateA(0.5) }

                    VialRow {
                        label: "cpu"
                        value: root.cpuPercent
                        tone: root.tone(root.cpuPercent, 60, 85)
                        readout: root.cpuPercent < 0 ? "--"
                            : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
                    }
                    VialRow {
                        label: "memory"
                        value: root.ramPercent
                        tone: root.tone(root.ramPercent, 70, 90)
                        readout: root.ramPercent < 0 ? "--"
                            : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
                    }
                    VialRow {
                        visible: root.hasGpu
                        height: root.hasGpu ? 30 : 0
                        label: "gpu"
                        value: root.gpuPercent
                        tone: root.tone(root.gpuPercent, 60, 85)
                        readout: root.gpuPercent + "% " + root.gpuTemp + "°"
                    }
                    VialRow {
                        visible: root.hasBattery
                        height: root.hasBattery ? 30 : 0
                        label: "charge"
                        value: root.batteryPercent
                        tone: root.batteryCharging ? root.skinLight
                            : root.batteryPercent <= 15 ? root.warmth
                            : root.batteryPercent <= 30 ? root.warn : root.paneLight
                        readout: (root.batteryCharging ? "⌁ " : "") + root.batteryPercent + "%"
                    }

                    // net: the connection, and what's drifting through it
                    Item {
                        width: parent.width
                        height: 24
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "net"
                                font.family: root.serif
                                font.italic: true
                                font.pixelSize: 13
                                color: root.inkA(0.72)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String.fromCodePoint(root.online
                                    ? (root.connType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
                                font.family: root.icon
                                font.pixelSize: 11
                                color: root.online ? root.paneA(0.9)
                                     : Qt.rgba(root.warmth.r, root.warmth.g, root.warmth.b, 0.9)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.online ? root.connName : "offline"
                                textFormat: Text.PlainText
                                font.family: root.mono
                                font.pixelSize: 11
                                color: root.online ? root.inkA(0.72)
                                     : Qt.rgba(root.warmth.r, root.warmth.g, root.warmth.b, 0.9)
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                            font.family: root.mono
                            font.pixelSize: 10
                            color: root.slateA(1.0)
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.slateA(0.5) }

                    // the foot: how long the glass has been awake
                    Item {
                        width: parent.width
                        height: 18
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "up " + root.uptimeText
                            font.family: root.serif
                            font.italic: true
                            font.pixelSize: 11
                            color: root.inkA(0.55)
                        }
                    }
                }
            }
        }
    }
}
