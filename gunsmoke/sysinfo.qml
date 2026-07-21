import QtQuick
import Quickshell
import Quickshell.Io

// gunsmoke: the system readout — a paper slip nailed to the post at the
// top-right, under the bar's skull. Hidden until called: hovering the skull
// (or Super+. pinning) reveals it, and the slip swings on its nail — a
// physical settle, damping to rest. Ledger law throughout: double rules,
// dotted leaders, letterspaced serif labels, mono data. Each subsystem is
// an entry with a row of ten powder marks that fill as load rises — hot
// entries burn brass, critical ones bleed the withheld oxblood.
// Reads /proc + nmcli itself; self-contained, click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color bone: pal.neon
    readonly property color blood: pal.magenta
    readonly property color brass: pal.amber
    readonly property color ash: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function ashA(a)   { return Qt.rgba(ash.r, ash.g, ash.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
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

    function tone(v, w, c) { return v >= c ? blood : v >= w ? brass : bone }

    // ── hover / pin reveal (flag files written by the bar skull + Super+.) ──
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    // smoke law: the slip fades off slower than it arrives
    Behavior on showT { NumberAnimation { duration: shown ? 200 : 420; easing.type: Easing.OutCubic } }
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

    // ── pollers — only while the slip is up; reveal refreshes instantly ────
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

    // ── an entry: label, dotted leader, powder-mark gauge, readout ─────────
    component EntryRow: Item {
        id: row
        property string label: "CPU"
        property int value: -1        // 0..100, -1 leaves the marks empty
        property color toneCol: root.bone
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.serif
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 3
            color: root.inkA(0.85)
        }
        // dotted leader, ledger style
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: 5
                Rectangle { width: 1.5; height: 1.5; radius: 0.75; color: root.ashA(0.8); anchors.verticalCenter: parent.verticalCenter }
            }
        }
        // ten powder marks
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 86
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 10)
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: lit ? row.toneCol : "transparent"
                    border.width: 1
                    border.color: lit ? row.toneCol : root.ashA(0.6)
                    opacity: lit ? 0.95 : 0.75
                    Behavior on color { ColorAnimation { duration: 240 } }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: root.inkA(0.7)
        }
    }

    // ── the slip, nailed under the bar's skull ─────────────────────────────
    Item {
        id: slip
        width: 320 * pal.uiScale
        height: card.height * pal.uiScale
        anchors.right: parent.right
        anchors.rightMargin: Math.round(18 * pal.uiScale)
        y: Math.round(10 * pal.uiScale)
        visible: root.showT > 0.01
        opacity: root.showT
        // the nail sits top-center; the slip hangs and swings from it
        transformOrigin: Item.Top
        rotation: 0
        // the settle: swings on its nail and damps to rest
        SequentialAnimation {
            id: sway
            running: false
            NumberAnimation { target: slip; property: "rotation"; to: -2.6; duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: slip; property: "rotation"; to: 1.8; duration: 210; easing.type: Easing.InOutSine }
            NumberAnimation { target: slip; property: "rotation"; to: -0.9; duration: 230; easing.type: Easing.InOutSine }
            NumberAnimation { target: slip; property: "rotation"; to: 0.4; duration: 240; easing.type: Easing.InOutSine }
            NumberAnimation { target: slip; property: "rotation"; to: 0; duration: 260; easing.type: Easing.InOutSine }
        }

        Column {
            id: card
            width: 320
            anchors.right: parent.right
            scale: pal.uiScale
            transformOrigin: Item.TopRight

            Item {
                width: parent.width
                height: paperCol.height + 34

                // the paper
                Rectangle {
                    anchors.fill: parent
                    color: root.glassA(0.93)
                    border.width: 1
                    border.color: root.ashA(0.7)
                }
                // double rule inside the top edge
                Rectangle { x: 10; y: 7; width: parent.width - 20; height: 1; color: root.boneA(0.35) }
                Rectangle { x: 10; y: 10; width: parent.width - 20; height: 1; color: root.boneA(0.14) }
                // the nail
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -3
                    width: 6; height: 6; radius: 3
                    color: root.boneA(0.85)
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.6)
                }
                // corner rivets, foot
                Rectangle { x: 4; y: parent.height - 7; width: 2.5; height: 2.5; radius: 1.25; color: root.boneA(0.35) }
                Rectangle { x: parent.width - 7; y: parent.height - 7; width: 2.5; height: 2.5; radius: 1.25; color: root.boneA(0.35) }

                Column {
                    id: paperCol
                    x: 18
                    y: 20
                    width: parent.width - 36
                    spacing: 2

                    EntryRow {
                        label: "CPU"
                        value: root.cpuPercent
                        toneCol: root.tone(root.cpuPercent, 62, 87)
                        readout: (root.cpuPercent >= 0 ? root.cpuPercent + "%" : "—")
                                 + (root.cpuTemp > 0 ? " · " + root.cpuTemp + "°" : "")
                    }
                    EntryRow {
                        label: "MEM"
                        value: root.ramPercent
                        toneCol: root.tone(root.ramPercent, 70, 90)
                        readout: root.ramPercent >= 0
                                 ? root.ramUsedGb.toFixed(1) + "/" + Math.round(root.ramTotalGb) + "G" : "—"
                    }
                    EntryRow {
                        visible: root.hasGpu
                        label: "GPU"
                        value: root.gpuPercent
                        toneCol: root.tone(root.gpuPercent, 62, 87)
                        readout: (root.gpuPercent >= 0 ? root.gpuPercent + "%" : "—")
                                 + (root.gpuTemp > 0 ? " · " + root.gpuTemp + "°" : "")
                    }
                    EntryRow {
                        label: "NET"
                        value: -1
                        readout: root.online
                                 ? "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                                 : "DOWN"
                    }
                    EntryRow {
                        visible: root.hasBattery
                        label: "BAT"
                        value: root.batteryPercent
                        toneCol: root.batteryPercent <= 15 ? root.blood
                               : root.batteryPercent <= 30 ? root.brass : root.bone
                        readout: root.batteryPercent >= 0
                                 ? root.batteryPercent + "%" + (root.batteryCharging ? " ⌁" : "") : "—"
                    }

                    // foot: rule + the connection's name + uptime
                    Item { width: 1; height: 6 }
                    Rectangle { width: parent.width; height: 1; color: root.boneA(0.25) }
                    Item { width: 1; height: 4 }
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? (root.connName || "online") : "offline"
                            textFormat: Text.PlainText
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            color: root.online ? root.inkA(0.7) : Qt.rgba(root.blood.r, root.blood.g, root.blood.b, 0.85)
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "up " + root.uptimeText
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            color: root.ashA(1)
                        }
                    }
                }
            }
        }
    }
}
