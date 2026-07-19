import QtQuick
import Quickshell
import Quickshell.Io

// sleeper: the BERTH CARD — the little service card the attendant keeps in
// the door slot, listing what the compartment is drawing tonight. Hover the
// card slot in the bar (or pin with Super+.) and the card slides out of its
// slot at the top right and settles with one damped sway on the carriage
// rhythm. Every subsystem is a service line — CPU, MEM, GPU, NET, PWR — and
// its meter is the house punch language: ten punch circles, one punched
// through per tenth of load (running hot re-inks the punches tea-amber, then
// stamp-red). Uptime runs along the foot as DISTANCE. Sections with no
// source (no nvidia-smi, no battery) stay unprinted. Reads /proc + nmcli
// itself; self-contained, click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color green: pal.neon
    readonly property color moonpale: pal.cyan
    readonly property color stamp: pal.magenta
    readonly property color tea: pal.amber
    readonly property color wood: pal.dim
    readonly property color linen: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function linenA(a) { return Qt.rgba(linen.r, linen.g, linen.b, a) }
    function teaA(a)   { return Qt.rgba(tea.r, tea.g, tea.b, a) }
    function woodA(a)  { return Qt.rgba(wood.r, wood.g, wood.b, a) }
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

    function tone(v, w, c) { return v >= c ? stamp : v >= w ? tea : green }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // hover reveal — the bar's card slot writes "1"/"0" here while hovered
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
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

    // ── pollers — only while the card is out ────────────────────────────────
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

    // ── a service line: label, ten punch circles, readout ───────────────────
    component ServiceRow: Item {
        id: row
        property string label: "CPU"
        property int value: -1        // 0..100, -1 = unprinted
        property color tone: root.green
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 3
            color: root.linenA(0.85)
        }

        // the punch row: circles punched through, one per tenth
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: 10
                delegate: Item {
                    required property int index
                    readonly property bool punched: row.value >= 0 && index < Math.round(row.value / 10)
                    width: 10; height: 10
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {   // the printed circle
                        anchors.fill: parent
                        radius: 5
                        color: "transparent"
                        border.width: 1
                        border.color: parent.punched ? row.tone : root.linenA(0.28)
                        Behavior on border.color { ColorAnimation { duration: 240 } }
                    }
                    Rectangle {   // the hole, punched through to the door's dark
                        anchors.centerIn: parent
                        width: 6; height: 6; radius: 3
                        color: Qt.rgba(0, 0, 0, 0.65)
                        visible: parent.punched
                        scale: parent.punched ? 1 : 1.6
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
            color: row.value >= 0 ? row.tone : root.woodA(1.0)
        }
    }

    // ── the card, sliding out of its slot at the top right ──────────────────
    Rectangle {
        id: card
        width: 296
        height: col.implicitHeight + 30
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 26 - 34 * (1 - root.showT)   // slides out of the slot
        anchors.topMargin: 54
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // one damped sway as it's pulled — the carriage settles it
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -2.2; to: 1.0; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: -0.4; duration: 540; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.4; to: 0; duration: 440; easing.type: Easing.OutSine }
        }

        radius: 4
        color: root.glassA(0.88)
        border.width: 1
        border.color: root.teaA(0.4)

        // the card's linen face — a paper tint over the glass
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 3
            color: Qt.rgba(root.linen.r, root.linen.g, root.linen.b, 0.05)
        }
        // punched corner hole, like the bar's little card
        Rectangle {
            x: 10; y: 10; width: 6; height: 6; radius: 3
            color: Qt.rgba(0, 0, 0, 0.6)
            border.width: 1
            border.color: root.teaA(0.5)
        }
        // perforation down the left edge — torn from the attendant's book
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: Math.max(3, Math.floor((card.height - 40) / 11))
                Rectangle { width: 1; height: 5; color: root.linenA(0.25) }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            anchors.topMargin: 14
            spacing: 4

            // header
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CAR 7 · BERTH CARD"
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    color: root.tea
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "НОЧНОЙ"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.woodA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.woodA(0.6) }

            ServiceRow {
                label: "CPU"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            ServiceRow {
                label: "MEM"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            ServiceRow {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                label: "GPU"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            ServiceRow {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                label: "PWR"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.moonpale
                    : root.batteryPercent <= 15 ? root.stamp
                    : root.batteryPercent <= 30 ? root.tea : root.green
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // NET is a written line: name left, rates right
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
                        font.pixelSize: 11
                        font.letterSpacing: 3
                        color: root.linenA(0.85)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online
                            ? String.fromCodePoint(root.connType === "eth" ? 0xF059F : 0xF05A9)
                            : String.fromCodePoint(0xF092F)
                        font.family: root.icon
                        font.pixelSize: 11
                        color: root.online ? root.green : root.stamp
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "OFF THE LINE"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.linenA(0.8) : root.stamp
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.woodA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.woodA(0.6) }

            // the foot: distance travelled + the send-off
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DISTANCE " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.linenA(0.6)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "☾ sleep well"
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.teaA(0.6)
                }
            }
        }
    }
}
