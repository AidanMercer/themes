import QtQuick
import Quickshell
import Quickshell.Io

// thicket: WHAT IT KNOWS — the watcher's tally, revealed only when you meet
// its eye in the bar (hover) or pin it (Super+.). A leaf-bitten panel parts
// out of the top-right foliage with one quick dart and a leafy shudder, then
// holds dead still. Each subsystem is a row the watcher keeps count of —
// CPU, MEM, GPU, NET, PWR — metered in ten leaf pips that flush from shadow
// grey-green to ember as load rises (hot rows go full ember-red). Sections
// with no source (no nvidia-smi, no battery) never appear: the watcher
// doesn't note what isn't there. Polls run ONLY while shown. Click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color emberRed: pal.magenta
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function emberA(a) { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)  { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function leafA(a)  { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
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

    function tone(v, w, c) { return v >= c ? emberRed : v >= w ? dapple : ember }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }

    // hover reveal — the bar's eye writes "1"/"0" here while hovered; the
    // tally stays hidden in the leaves until it's met
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
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

    // ── pollers — only while the tally is actually up ───────────────────────
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

    // ── a tally row: label, ten leaf pips, readout ──────────────────────────
    component TallyRow: Item {
        id: row
        property string label: "CPU"
        property int value: -1        // 0..100, -1 leaves the pips in shadow
        property color tone: root.ember
        property string readout: ""
        width: parent ? parent.width : 0
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 3
            color: root.inkA(0.8)
        }

        // ten leaf pips, each a small blade leaning right; lit ones flush warm
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 52
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9; height: 4; radius: 2
                    rotation: -24
                    color: lit ? row.tone : root.leafA(0.55)
                    opacity: lit ? 0.95 : 0.7
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tone : root.leafA(1.0)
        }
    }

    // ── the tally panel, parting out of the top-right foliage ──────────────
    Item {
        id: panel
        width: 296
        height: card.height + 22
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 24
        anchors.topMargin: 52 - 8 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // pushed through the leaves: a quick lean and it settles still
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -2.4; to: 1.0; duration: 240; easing.type: Easing.OutQuint }
            NumberAnimation { from: 1.0; to: -0.3; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.3; to: 0; duration: 220; easing.type: Easing.OutSine }
        }

        Rectangle {
            id: card
            width: parent.width
            height: col.implicitHeight + 30
            y: 10
            radius: 10
            color: root.glassA(0.86)
            border.width: 1
            border.color: root.leafA(0.6)

            // dapple pooled in the panel's upper reach
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 40
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.dapple.r, root.dapple.g, root.dapple.b, 0.09) }
                    GradientStop { position: 1.0; color: "transparent" }
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

                // header: the eyes, met
                Item {
                    width: parent.width
                    height: 18
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        // the pair of glints
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15; height: 5
                            Rectangle { x: 0; y: 1; width: 5; height: 3.5; radius: 1.75; color: root.iris }
                            Rectangle { x: 9; y: 0; width: 5; height: 3.5; radius: 1.75; color: root.iris }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "WHAT IT KNOWS"
                            font.family: root.mono
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            font.letterSpacing: 3
                            color: root.emberA(0.95)
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FROM COVER"
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: root.leafA(1.0)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.leafA(0.55) }

                TallyRow {
                    label: "CPU"
                    value: root.cpuPercent
                    tone: root.tone(root.cpuPercent, 60, 85)
                    readout: root.cpuPercent < 0 ? "--"
                        : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
                }
                TallyRow {
                    label: "MEM"
                    value: root.ramPercent
                    tone: root.tone(root.ramPercent, 70, 90)
                    readout: root.ramPercent < 0 ? "--"
                        : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
                }
                TallyRow {
                    visible: root.hasGpu
                    height: root.hasGpu ? 28 : 0
                    label: "GPU"
                    value: root.gpuPercent
                    tone: root.tone(root.gpuPercent, 60, 85)
                    readout: root.gpuPercent + "% " + root.gpuTemp + "°"
                }
                TallyRow {
                    visible: root.hasBattery
                    height: root.hasBattery ? 28 : 0
                    label: "PWR"
                    value: root.batteryPercent
                    tone: root.batteryCharging ? root.iris
                        : root.batteryPercent <= 15 ? root.emberRed
                        : root.batteryPercent <= 30 ? root.dapple : root.ember
                    readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
                }

                // NET is text-only: what it hears on the wind
                Item {
                    width: parent.width
                    height: 24
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "NET"
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 3
                            color: root.inkA(0.8)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online
                                ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                                : String.fromCodePoint(0xF092F)
                            font.family: root.icon
                            font.pixelSize: 11
                            color: root.online ? root.irisA(0.9) : root.emberRed
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? root.connName : "NOTHING STIRS"
                            textFormat: Text.PlainText
                            font.family: root.mono
                            font.pixelSize: 10
                            color: root.online ? root.inkA(0.8) : root.emberRed
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                        font.family: root.mono
                        font.pixelSize: 9
                        color: root.leafA(1.0)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.leafA(0.55) }

                // how long it has been watching
                Item {
                    width: parent.width
                    height: 18
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WATCHED " + root.uptimeText
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: root.inkA(0.55)
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "still. then gone."
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: 10
                        color: root.emberA(0.6)
                    }
                }
            }
        }

        // the leaves the panel was pushed through, biting its rim — one draw
        Canvas {
            id: rimLeaves
            anchors.fill: parent
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onDimChanged() { rimLeaves.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                function leafShape(x, y, len, wid, ang, fill) {
                    ctx.save()
                    ctx.translate(x, y); ctx.rotate(ang)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                    ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                    ctx.closePath()
                    ctx.fillStyle = fill
                    ctx.fill()
                    ctx.restore()
                }
                for (let i = 0; i < 9; i++) {
                    const top = i < 5
                    const f = top ? i / 4 : (i - 5) / 3
                    const x = top ? w * (0.08 + f * 0.8) : w * (0.25 + f * 0.66)
                    const y = top ? 10 + (root.rnd(i * 7) - 0.5) * 6
                                  : h - 4 + (root.rnd(i * 7) - 0.5) * 5
                    const ang = (top ? 0.4 : -0.5) + (root.rnd(i * 31 + 2) - 0.5) * 1.1 + (top ? Math.PI : 0)
                    const teal = root.rnd(i * 41 + 6) < 0.3
                    leafShape(x, y, 16 + root.rnd(i * 17 + 9) * 14, 4.5 + root.rnd(i * 23) * 3,
                              ang, teal ? "rgba(26,48,42,0.9)" : "rgba(8,13,11,0.88)")
                }
            }
        }
    }
}
