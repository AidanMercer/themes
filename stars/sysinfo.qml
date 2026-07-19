import QtQuick
import Quickshell
import Quickshell.Io

// stars: the vending machine's service panel, pinned into the dark ground of
// the bottom-right corner. A diagnostic readout styled like the machine's
// own front: each subsystem is a product slot — "A1 CPU", "B2 MEM", "C3
// GPU", "D4 NET", "E5 PWR" — with a shelf of little bottle-lights filling
// bottom-dim to bright-amber as load rises (overheating slots go coral, then
// signal red). A coin counter ticks the uptime along the bottom. Sections
// with no source (no nvidia-smi, no battery) stay dark like empty slots.
// Reads /proc + nmcli itself; self-contained, click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color alert: pal.magenta
    readonly property color warm:  pal.amber
    readonly property color slate: pal.dim
    readonly property color ink:   pal.text
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

    // boot-in: the panel hums awake
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    // hover reveal — the bar's service bottle writes "1"/"0" here while
    // hovered; the panel stays shut until a technician calls
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
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
    // Super+. pin — the shell writes "1"/"0" here (`qs ipc call sysinfo toggle`);
    // pinned keeps the panel dropped without calling the technician
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
    // poll only while the panel is actually up (reveal refreshes instantly via triggeredOnStart)
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

    // ── a product-slot row: code tag, label, bottle-shelf meter, readout ────
    component SlotRow: Item {
        id: row
        property string code: "A1"
        property string label: "CPU"
        property int value: -1        // 0..100, -1 hides the shelf fill
        property color tone: root.amber
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {   // slot code, like the machine's keypad tags
            id: codeTag
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.code
            font.family: root.mono
            font.pixelSize: 10
            font.weight: Font.Bold
            color: root.slateA(1.0)
        }
        Text {
            id: labelText
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 2
            color: root.inkA(0.85)
        }

        // the shelf: 10 bottle-lights that fill with the level
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 70
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 10)
                    width: 7; height: 13; radius: 2.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: lit ? row.tone : "transparent"
                    border.width: 1
                    border.color: lit ? row.tone : root.slateA(0.55)
                    opacity: lit ? 0.95 : 0.8
                    Behavior on color { ColorAnimation { duration: 240 } }
                    // cap tick on each bottle
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -2
                        width: 3; height: 2; radius: 0.5
                        color: parent.lit ? row.tone : root.slateA(0.55)
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
            color: row.value >= 0 ? row.tone : root.slateA(1.0)
        }
    }

    // ── the panel, machine-front chrome — drops from the wire on hover ──────
    Rectangle {
        id: panel
        width: 300
        height: col.implicitHeight + 30
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 28
        anchors.topMargin: 56 - 10 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // swings on its wire as it drops, settles plumb
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -3.0; to: 1.3; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.3; to: -0.5; duration: 550; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.5; to: 0; duration: 450; easing.type: Easing.OutSine }
        }

        radius: 11
        color: root.glassA(0.82)
        border.width: 1
        border.color: root.amberA(0.4)

        // warm interior glow along the top, like light leaking from the shelves
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 44
            radius: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.amberA(0.10) }
                GradientStop { position: 1.0; color: root.amberA(0.0) }
            }
        }
        // the machine's coin slot, top right of the panel face
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 14
            anchors.rightMargin: 16
            width: 4; height: 14; radius: 2
            color: "transparent"
            border.width: 1
            border.color: root.slateA(0.9)
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

            // header: the lit vendor sign
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        font.pixelSize: 11
                        color: root.amber
                        SequentialAnimation on opacity {
                            running: root.bootT >= 1 && root.shown && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SEASIDE VENDOR"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        color: root.amber
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SELF-CHECK"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.slateA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.slateA(0.6) }

            SlotRow {
                code: "A1"; label: "CPU"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            SlotRow {
                code: "B2"; label: "MEM"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            SlotRow {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                code: "C3"; label: "GPU"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            SlotRow {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                code: "E5"; label: "PWR"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.coral
                    : root.batteryPercent <= 15 ? root.alert
                    : root.batteryPercent <= 30 ? root.warm : root.amber
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // NET is text-only: name left, rates right
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "D4"
                        font.family: root.mono
                        font.pixelSize: 10
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
                        color: root.online ? root.coral : root.alert
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

            // coin counter: uptime
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8; radius: 4
                            color: "transparent"
                            border.width: 1.2
                            border.color: root.amberA(index === 0 ? 0.9 : index === 1 ? 0.55 : 0.3)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: " UP " + root.uptimeText
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: root.inkA(0.6)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✧ WAITING WITH STARS"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: root.amberA(0.5)
                }
            }
        }
    }
}
