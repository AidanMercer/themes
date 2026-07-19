import QtQuick
import Quickshell
import Quickshell.Io

// bog: the depth soundings. Hover the cattail in the bar (or pin with
// Super+.) and a bark-dark float panel surfaces top-right — rising through
// its own waterline with a buoyant roll that damps out, the way a leaf
// settles after a toad steps off it. Every metric is a STRING OF TEN CORK
// FLOATS on a line: load pulls floats UNDER one by one (a submerged float
// sinks below the line and dims to moss — something heavy is on that line).
// CPU is the current, RAM the silt, GPU the deep pool, the battery a firefly
// jar, the network a dragonfly. Sections with no source never light. Reads
// /proc + nmcli itself; polls only while revealed; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color warm: pal.amber
    readonly property color reed: pal.dim
    readonly property color straw: pal.text
    readonly property color murk: pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function strawA(a) { return Qt.rgba(straw.r, straw.g, straw.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a)  { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a)  { return Qt.rgba(reed.r, reed.g, reed.b, a) }
    function murkA(a)  { return Qt.rgba(murk.r, murk.g, murk.b, a) }

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

    function tone(v, w, c) { return v >= c ? rust : v >= w ? warm : sun }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutSine }

    // hover reveal — the bar's cattail writes "1"/"0" here while hovered
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) settle.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 500; easing.type: Easing.OutSine } }
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

    // ── pollers (only while the soundings are actually up) ──────────────────
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

    // ── a sounding line: name, ten floats on a line, readout ────────────────
    component SoundingRow: Item {
        id: row
        property string label: "the current"
        property int value: -1        // 0..100, -1 leaves the string slack
        property color tone: root.sun
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.serif
            font.italic: true
            font.pixelSize: 12
            color: root.strawA(0.85)
        }

        // the line the floats hang on
        Item {
            id: meter
            anchors.left: parent.left
            anchors.leftMargin: 108
            anchors.verticalCenter: parent.verticalCenter
            width: 118; height: 18
            readonly property int under: row.value < 0 ? 0 : Math.round(row.value / 100 * 10)
            Rectangle {
                y: 8
                width: parent.width
                height: 1
                color: root.reedA(0.6)
            }
            Row {
                spacing: 5
                Repeater {
                    model: 10
                    delegate: Item {
                        required property int index
                        // floats fill under from the LEFT — the near ones take
                        // the weight first
                        readonly property bool sunk: index < meter.under
                        width: 7; height: 18
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: sunk ? 10 : 4
                            width: 5; height: 5
                            radius: 2.5
                            color: sunk ? root.mossA(0.45) : row.tone
                            Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.InOutSine } }
                            Behavior on color { ColorAnimation { duration: 500 } }
                        }
                        // a stem above a float still riding proud
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 1; width: 1; height: 3
                            color: Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.6)
                            visible: !sunk
                        }
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tone : root.reedA(1.0)
        }
    }

    // ── the panel, surfacing top-right ──────────────────────────────────────
    Item {
        id: panel
        width: 330
        height: face.height
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 28
        anchors.topMargin: 52 + 20 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // the buoyant settle: it breaks the surface, rolls, and damps flat
        SequentialAnimation on rotation {
            id: settle
            running: false
            NumberAnimation { from: -2.2; to: 1.1; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.1; to: -0.5; duration: 540; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.5; to: 0; duration: 480; easing.type: Easing.OutSine }
        }
        // and its resting bob while it stays up
        property real bobY: 0
        transform: Translate { y: panel.bobY }
        SequentialAnimation on bobY {
            running: root.shown && !root.occluded
            loops: Animation.Infinite
            NumberAnimation { to: 2; duration: 4600; easing.type: Easing.InOutSine }
            NumberAnimation { to: -2; duration: 4600; easing.type: Easing.InOutSine }
        }

        Rectangle {
            id: face
            width: parent.width
            height: col.implicitHeight + 34
            radius: 16
            color: root.murkA(0.90)
            border.width: 1
            border.color: root.mossA(0.35)
        }
        // the waterline through the panel, under the header
        Rectangle {
            x: 14; y: 40
            width: parent.width - 28
            height: 1
            color: root.reedA(0.55)
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: 20 + index * 78
                y: 39
                width: index % 2 === 0 ? 18 : 9
                height: 2
                radius: 1
                color: root.sunA(0.3)
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 12
            spacing: 5

            // header: a cork pip slowly dipping + the panel's name
            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 10
                        property real dip: 0
                        Rectangle { x: 0; y: 0 + parent.dip; width: 7; height: 4.4; radius: 2.2; color: root.rust }
                        Rectangle { x: 1; y: 3.8 + parent.dip; width: 5; height: 3.6; radius: 1.8; color: root.sunA(0.85) }
                        SequentialAnimation on dip {
                            running: root.shown && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.8; duration: 1700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -0.6; duration: 1700; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "depth soundings"
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: 15
                        color: root.sun
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "slow noon"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.reedA(1.0)
                }
            }

            Item { width: parent.width; height: 10 }   // room for the waterline

            SoundingRow {
                label: "the current"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            SoundingRow {
                label: "the silt"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            SoundingRow {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                label: "the deep pool"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            SoundingRow {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                label: "the firefly jar"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.moss
                    : root.batteryPercent <= 15 ? root.rust
                    : root.batteryPercent <= 30 ? root.warm : root.sun
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // the dragonfly is text-only: connection left, rates right
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "the dragonfly"
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: 12
                        color: root.strawA(0.85)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.online ? root.moss : root.rust
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "flown off"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.strawA(0.75) : root.rust
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.reedA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.reedA(0.4) }

            // the foot: how long we've been afloat
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "afloat " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.strawA(0.55)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "≈ the pond keeps its own time"
                    font.family: root.serif
                    font.italic: true
                    font.pixelSize: 10
                    color: root.sunA(0.5)
                }
            }
        }
    }
}
