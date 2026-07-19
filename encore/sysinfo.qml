import QtQuick
import Quickshell
import Quickshell.Io

// encore: the PATCH BAY — the rack panel behind the light desk. Hover the
// DESK lamp on the bar (or pin with Super+.) and the panel drops in on its
// lighting batten, swings once and hangs plumb (the physical settle). Every
// subsystem is a channel on the rig: CH1 VOX (CPU), CH2 KEYS (MEM), CH3
// SYNTH (GPU), CH4 FOH (NET), CH5 PWR — each metered by a ten-lamp LED
// ladder that fills in whole lamps only (law 1). Hot channels go follow-spot
// warm, clipping channels go crowd magenta (law 4). Channels with no source
// stay dark, unpatched. Reads /proc + nmcli itself; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color teal: pal.neon
    readonly property color lacquer: pal.cyan
    readonly property color crowd: pal.magenta
    readonly property color spot: pal.amber
    readonly property color rest: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function tealA(a) { return Qt.rgba(teal.r, teal.g, teal.b, a) }
    function restA(a) { return Qt.rgba(rest.r, rest.g, rest.b, a) }
    function glassA(a){ return Qt.rgba(glass.r, glass.g, glass.b, a) }

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

    function tone(v, w, c) { return v >= c ? crowd : v >= w ? spot : teal }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }

    // hover reveal — the bar's DESK lamp writes "1"/"0"; Super+. pins
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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

    // ── pollers — only while the panel is actually up ───────────────────────
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

    // ── a channel row: CH tag, instrument, ten-lamp ladder, readout ─────────
    component ChannelRow: Item {
        id: row
        property string ch: "CH1"
        property string label: "VOX"
        property int value: -1        // 0..100, -1 = unpatched
        property color tone: root.teal
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.ch
            font.family: root.mono
            font.pixelSize: 9
            font.weight: Font.Bold
            color: root.restA(1.0)
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

        // the ladder: ten lamps, whole lamps only — an LED meter, not a bar
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 82
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 10)
                    // the top two lamps are always warm/magenta caps when lit —
                    // a real LED ladder's clip lamps
                    readonly property color lampCol: index >= 9 ? root.crowd
                                                   : index >= 7 ? root.spot
                                                   : row.tone
                    width: 6; height: 12; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: lit ? lampCol : "transparent"
                    border.width: 1
                    border.color: lit ? lampCol : root.restA(0.5)
                    opacity: lit ? 0.95 : 0.75
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tone : root.restA(1.0)
        }
    }

    // ── the rack panel, dropped in on its batten ────────────────────────────
    Rectangle {
        id: panel
        width: 310
        height: col.implicitHeight + 30
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 26
        anchors.topMargin: Math.round(root.height * 0.315) - 12 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.Top

        // the batten swing: drops, overshoots, hangs plumb
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -2.4; to: 1.1; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.1; to: -0.4; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.4; to: 0; duration: 400; easing.type: Easing.OutSine }
        }

        radius: 12
        color: root.glassA(0.85)
        border.width: 1
        border.color: root.tealA(0.35)

        // the batten wire, up out of the panel's shoulders
        Rectangle { x: parent.width * 0.24; y: -22; width: 1; height: 22; color: root.restA(0.7) }
        Rectangle { x: parent.width * 0.76; y: -22; width: 1; height: 22; color: root.restA(0.7) }

        // the teal edge-strip foot — the desk's signature
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 30
            height: 2
            radius: 1
            color: root.tealA(0.5)
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

            // header: the rack's name + a cue lamp on the count
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        id: rackLamp
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        property bool tick: true
                        color: tick ? root.teal : root.restA(0.7)
                        Timer {
                            interval: 500; repeat: true
                            running: root.shown && !root.occluded
                            onTriggered: rackLamp.tick = !rackLamp.tick
                        }
                        onVisibleChanged: if (!visible) tick = true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PATCH BAY"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 4
                        color: root.teal
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "LINE CHECK"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.restA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.restA(0.55) }

            ChannelRow {
                ch: "CH1"; label: "VOX"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            ChannelRow {
                ch: "CH2"; label: "KEYS"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            ChannelRow {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                ch: "CH3"; label: "SYNTH"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            ChannelRow {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                ch: "CH5"; label: "PWR"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.lacquer
                    : root.batteryPercent <= 15 ? root.crowd
                    : root.batteryPercent <= 30 ? root.spot : root.teal
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // FOH is text-only: the desk's link to the house
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CH4"
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: root.restA(1.0)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FOH"
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: root.inkA(0.85)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "LINK DOWN"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.tealA(0.9) : root.crowd
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.restA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.restA(0.55) }

            // the show timer
            Item {
                width: parent.width
                height: 18
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SHOW RUNNING " + root.uptimeText
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: root.inkA(0.6)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "V// ENCORE"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.tealA(0.55)
                }
            }
        }
    }
}
