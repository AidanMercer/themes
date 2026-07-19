import QtQuick
import Quickshell
import Quickshell.Io
import "chalk.js" as Chalk

// homeroom: the duty board. Hover the thumbtack in the rail (or pin with
// Super+.) and a small slate swings down on its two tape tabs, settling on
// its pins the way a hung board takes a knock. The day's subjects are the
// machine's vitals — MATH is the CPU, MEMORY is RAM, ART the GPU, ENERGY
// the battery, ATTENDANCE the network — and every meter is chalk tally
// marks, four strokes and a diagonal gate, one tally-stroke per 10%.
// Sections with no source (no nvidia-smi, no battery) never appear. Reads
// /proc + nmcli itself; polls only while revealed; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    readonly property color slate: pal.dim
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

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

    // chalk color by pressure: white → sunlight → stripe pink
    function tone(v, w, c) { return v >= c ? pink : v >= w ? sun : chalk }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }

    // hover reveal — the rail's thumbtack writes "1"/"0" here while hovered
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

    // ── pollers — only while the board is actually up ───────────────────────
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

    // ── a subject row: name, chalk tallies, readout ────────────────────────
    component SubjectRow: Item {
        id: row
        property string subject: "MATH"
        property int value: -1        // 0..100, -1 = not chalked yet
        property color tone: root.chalk
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.subject
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 2
            color: root.chalkA(0.85)
        }

        // the tallies: one stroke per 10%, every fifth gates the four before
        Canvas {
            id: tally
            anchors.left: parent.left
            anchors.leftMargin: 108
            anchors.verticalCenter: parent.verticalCenter
            width: 118; height: 22
            property int strokes: row.value < 0 ? 0 : Math.max(0, Math.min(10, Math.round(row.value / 10)))
            property color tc: row.tone
            onStrokesChanged: requestPaint()
            onTcChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const col = String(Qt.rgba(tc.r, tc.g, tc.b, 1))
                for (let i = 0; i < strokes; i++) {
                    const grp = Math.floor(i / 5)
                    const pos = i % 5
                    const gx = 4 + grp * 58
                    if (pos < 4) {
                        Chalk.strokePath(ctx, [[gx + pos * 10, 3], [gx + pos * 10 + 1.5, 19]], {
                            seed: row.subject.charCodeAt(0) * 13 + i * 7,
                            color: col, alpha: 0.9, width: 2.2, dust: 0.08
                        })
                    } else {
                        Chalk.strokePath(ctx, [[gx - 4, 16], [gx + 34, 5]], {
                            seed: row.subject.charCodeAt(0) * 17 + i * 5,
                            color: col, alpha: 0.9, width: 2.4, dust: 0.10
                        })
                    }
                }
                // the empty ledger line under un-chalked space
                if (strokes < 10) {
                    Chalk.strokePath(ctx, [[4 + (strokes >= 5 ? 58 : 0), 21], [114, 21]], {
                        seed: 3, color: String(root.slateA(1)), alpha: 0.30, width: 1.4, ghost: false, dust: 0
                    })
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.95) : root.slateA(1.0)
        }
    }

    // ── the slate, hanging from its tape tabs top-right ────────────────────
    Item {
        id: board
        width: 330
        height: face.height + 8
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 24
        anchors.topMargin: 46 + 12 * root.showT
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.Top

        // the settle: the board takes a knock and swings level on its pins
        SequentialAnimation on rotation {
            id: settle
            running: false
            NumberAnimation { from: -2.2; to: 1.1; duration: 460; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.1; to: -0.5; duration: 400; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.5; to: 0; duration: 340; easing.type: Easing.OutSine }
        }

        // two tape tabs holding it up
        Rectangle { x: 34; y: -4; width: 22; height: 9; rotation: -35; color: root.chalkA(0.4) }
        Rectangle { x: board.width - 58; y: -4; width: 22; height: 9; rotation: 32; color: root.chalkA(0.4) }

        // the slate face, chalk-framed
        Rectangle {
            id: face
            width: parent.width
            height: col.implicitHeight + 32
            y: 4
            radius: 3
            color: root.glassA(0.92)
            border.width: 1
            border.color: root.slateA(0.6)
        }
        Canvas {   // hand-drawn chalk frame just inside the slate's edge
            id: frame
            anchors.fill: face
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height, m = 7
                Chalk.strokePath(ctx, [[m, m], [w - m, m + 1], [w - m - 1, h - m], [m + 1, h - m - 1], [m, m]], {
                    seed: 91, color: String(root.chalkA(1)), alpha: 0.30, width: 2, dust: 0.06
                })
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onTextChanged() { frame.requestPaint() }
            }
        }

        Column {
            id: col
            anchors.left: face.left
            anchors.right: face.right
            anchors.top: face.top
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 16
            spacing: 3

            // header: today's duty
            Item {
                width: parent.width
                height: 20
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {   // halo understudy pip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 4.5
                        color: "transparent"
                        border.width: 1.6
                        border.color: Qt.rgba(root.halo.r, root.halo.g, root.halo.b, 0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DUTY BOARD"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 4
                        color: root.chalkA(0.95)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "1st period"
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.slateA(1)
                }
            }

            Item { width: 1; height: 6 }

            SubjectRow {
                subject: "MATH"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            SubjectRow {
                subject: "MEMORY"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            SubjectRow {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                subject: "ART"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            SubjectRow {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                subject: "ENERGY"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.halo
                    : root.batteryPercent <= 15 ? root.pink
                    : root.batteryPercent <= 30 ? root.sun : root.chalk
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // ATTENDANCE is text-only: who's here, and how fast they talk
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ATTENDANCE"
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: root.chalkA(0.85)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? "present — " + root.connName : "absent"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.chalkA(0.7) : Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 0.95)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.online ? "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate) : ""
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.slateA(1.0)
                }
            }

            Item { width: 1; height: 4 }

            // the foot: how long the room's been open
            Item {
                width: parent.width
                height: 16
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "room open " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.chalkA(0.5)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "before the bell ☼"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.sunA(0.7)
                }
            }
        }
    }
}
