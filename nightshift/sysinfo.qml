import QtQuick
import Quickshell
import Quickshell.Io
import "windows.js" as W

// nightshift: the gondola. Hover the vitals in the bar (or pin with Super+.)
// and a window-washer's cradle comes down the face of the building on its two
// cables, swinging once before it settles — the wallpaper hangs its own cables
// off the left wall, and this is the same rig on the other side of the street.
//
// Every reading is a building: a labelled block that fills bottom-up. Labels
// stay plain (cpu, mem, gpu, net, batt, up) — the city does the world-building.
// Sections with no source (no nvidia-smi, no battery) never appear. Reads /proc
// and nmcli itself, polls ONLY while the cradle is down, click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color beacon: pal.magenta
    readonly property color lampAmber: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string sans: "Noto Sans"
    readonly property real ui: pal.uiScale
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function hazeA(a)   { return Qt.rgba(haze.r, haze.g, haze.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function sodiumA(a) { return Qt.rgba(sodium.r, sodium.g, sodium.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function tone(v, warn, crit) { return v >= crit ? beacon : v >= warn ? lampAmber : sodium }

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

    // ── reveal ──────────────────────────────────────────────────────────────
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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

    // ── pollers — only while the cradle is down ─────────────────────────────
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
            rxRate = Math.max(0, (rx - prevRx) / 2048)
            txRate = Math.max(0, (tx - prevTx) / 2048)
        }
        prevRx = rx; prevTx = tx
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE c show --active 2>/dev/null | head -1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseNet(text) }
    }
    function parseNet(raw) {
        const line = raw.trim()
        if (!line) { online = false; connName = ""; connType = ""; return }
        const f = line.split(":")
        online = true
        connName = f[0] || ""
        connType = (f[1] || "").indexOf("wireless") >= 0 ? "wifi"
                 : (f[1] || "").indexOf("ethernet") >= 0 ? "ethernet" : (f[1] || "")
    }

    Process {
        id: upProc
        command: ["cat", "/proc/uptime"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseFloat(text.trim().split(/\s+/)[0])
                if (isNaN(s)) return
                const d = Math.floor(s / 86400)
                const h = Math.floor((s % 86400) / 3600)
                const m = Math.floor((s % 3600) / 60)
                root.uptimeText = d > 0 ? (d + "d " + h + "h") : h > 0 ? (h + "h " + m + "m") : (m + "m")
            }
        }
    }

    // ── one reading: plain label, value, and a block that fills bottom-up ────
    component Reading: Item {
        id: rd
        property string label: ""
        property string value: ""
        property string note: ""
        property real level: 0
        property color hue: root.sodium
        width: parent ? parent.width : 0
        height: Math.round(34 * root.ui)

        Facade {
            id: blk
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            cols: 5; rows: 5
            cell: Math.round(4 * root.ui)
            gap: Math.max(1, Math.round(1.5 * root.ui))
            lit: rd.hue
            dark: root.slate
            darkAlpha: 0.34
            flicker: false
            occluded: root.occluded || !root.shown
            spread: 320
            plan: W.planLevel(W.blank(5, 5), 5, 5, rd.level)
        }
        Text {
            anchors.left: blk.right
            anchors.leftMargin: Math.round(11 * root.ui)
            anchors.verticalCenter: parent.verticalCenter
            text: rd.label
            color: root.hazeA(0.95)
            font.family: root.sans
            font.pixelSize: Math.round(11 * root.ui)
            font.letterSpacing: 1.6
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: rd.value + (rd.note ? "  " + rd.note : "")
            color: root.inkA(0.94)
            font.family: root.mono
            font.pixelSize: Math.round(12 * root.ui)
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── the cradle ──────────────────────────────────────────────────────────
    readonly property real cradleW: Math.round(320 * ui)

    Item {
        id: rig
        width: root.cradleW
        height: cradle.height
        x: root.width - width - Math.round(root.width * 0.045)
        y: Math.round(root.height * 0.11)
        opacity: root.showT
        visible: opacity > 0.01
        transformOrigin: Item.Top
        rotation: 0

        // the two cables, running off the top of the frame
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: index === 0 ? Math.round(26 * root.ui) : rig.width - Math.round(27 * root.ui)
                y: -rig.y
                width: 1
                height: rig.y
                color: root.slateA(0.9)
            }
        }

        // it drops in and swings — a cradle on cables never arrives level
        SequentialAnimation {
            id: sway
            running: false
            NumberAnimation { target: rig; property: "rotation"; to: 2.1; duration: 170; easing.type: Easing.OutQuad }
            NumberAnimation { target: rig; property: "rotation"; to: -1.3; duration: 300; easing.type: Easing.InOutSine }
            NumberAnimation { target: rig; property: "rotation"; to: 0.55; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: rig; property: "rotation"; to: 0; duration: 320; easing.type: Easing.OutSine }
        }

        Rectangle {
            id: cradle
            width: parent.width
            // margins spelled out rather than anchors.fill on the Column: the
            // card's height comes FROM the column, so filling it back would be
            // a loop and Qt would resolve it by clipping the readout in half
            readonly property real padX: Math.round(15 * root.ui)
            readonly property real padTop: Math.round(17 * root.ui)
            readonly property real padBottom: Math.round(30 * root.ui)
            height: col.implicitHeight + padTop + padBottom
            color: root.glassA(0.93)
            border.width: 1
            border.color: root.hazeA(0.32)
            radius: 2

            // the cradle's top rail, where the cables make off
            Rectangle {
                width: parent.width; height: Math.round(3 * root.ui)
                color: root.slateA(1)
            }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: cradle.padX
                anchors.rightMargin: cradle.padX
                anchors.topMargin: cradle.padTop
                spacing: Math.round(3 * root.ui)

                Row {
                    width: parent.width
                    spacing: Math.round(8 * root.ui)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(5 * root.ui); height: width
                        color: root.sodium
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "still up"
                        color: root.inkA(0.95)
                        font.family: root.sans
                        font.pixelSize: Math.round(13 * root.ui)
                        font.weight: Font.Medium
                        font.letterSpacing: 2.2
                    }
                }
                Rectangle {
                    width: parent.width; height: 1
                    color: root.slateA(0.9)
                }
                Item { width: 1; height: Math.round(5 * root.ui) }

                Reading {
                    label: "cpu"
                    level: Math.max(0, root.cpuPercent) / 100
                    hue: root.tone(root.cpuPercent, 75, 90)
                    value: root.cpuPercent < 0 ? "—" : root.cpuPercent + "%"
                    note: root.cpuTemp > 0 ? root.cpuTemp + "°" : ""
                }
                Reading {
                    label: "mem"
                    level: Math.max(0, root.ramPercent) / 100
                    hue: root.tone(root.ramPercent, 75, 90)
                    value: root.ramPercent < 0 ? "—" : root.ramPercent + "%"
                    note: root.ramTotalGb > 0
                        ? root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G" : ""
                }
                Reading {
                    visible: root.hasGpu
                    height: visible ? Math.round(34 * root.ui) : 0
                    label: "gpu"
                    level: Math.max(0, root.gpuPercent) / 100
                    hue: root.tone(root.gpuPercent, 75, 90)
                    value: root.gpuPercent < 0 ? "—" : root.gpuPercent + "%"
                    note: root.gpuTemp > 0 ? root.gpuTemp + "°" : ""
                }
                Reading {
                    visible: root.hasBattery
                    height: visible ? Math.round(34 * root.ui) : 0
                    label: "batt"
                    level: Math.max(0, root.batteryPercent) / 100
                    hue: root.batteryCharging ? root.haze
                       : root.batteryPercent <= 15 ? root.beacon
                       : root.batteryPercent <= 30 ? root.lampAmber : root.sodium
                    value: root.batteryPercent < 0 ? "—" : root.batteryPercent + "%"
                    note: root.batteryCharging ? "chg" : ""
                }

                Item { width: 1; height: Math.round(5 * root.ui) }
                Rectangle {
                    width: parent.width; height: 1
                    color: root.slateA(0.9)
                }
                Item { width: 1; height: Math.round(7 * root.ui) }

                // net and uptime read as words, not gauges — they aren't levels
                Row {
                    width: parent.width
                    Text {
                        text: "net"
                        color: root.hazeA(0.95)
                        font.family: root.sans
                        font.pixelSize: Math.round(11 * root.ui)
                        font.letterSpacing: 1.6
                    }
                    Item { width: Math.round(10 * root.ui); height: 1 }
                    Text {
                        width: parent.width - Math.round(45 * root.ui)
                        horizontalAlignment: Text.AlignRight
                        text: root.online ? (root.connName || root.connType || "up") : "offline"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.online ? root.inkA(0.94) : root.beacon
                        font.family: root.mono
                        font.pixelSize: Math.round(12 * root.ui)
                    }
                }
                Row {
                    width: parent.width
                    visible: root.online
                    Text {
                        text: ""
                        width: Math.round(35 * root.ui)
                        font.pixelSize: Math.round(11 * root.ui)
                    }
                    Text {
                        width: parent.width - Math.round(35 * root.ui)
                        horizontalAlignment: Text.AlignRight
                        text: "↓" + root.rxRate.toFixed(0) + "  ↑" + root.txRate.toFixed(0) + " KB/s"
                        color: root.inkA(0.74)
                        font.family: root.mono
                        font.pixelSize: Math.round(11 * root.ui)
                    }
                }
                Item { width: 1; height: Math.round(4 * root.ui) }
                Row {
                    width: parent.width
                    Text {
                        text: "up"
                        color: root.hazeA(0.95)
                        font.family: root.sans
                        font.pixelSize: Math.round(11 * root.ui)
                        font.letterSpacing: 1.6
                    }
                    Text {
                        width: parent.width - Math.round(25 * root.ui)
                        horizontalAlignment: Text.AlignRight
                        text: root.uptimeText
                        color: root.inkA(0.94)
                        font.family: root.mono
                        font.pixelSize: Math.round(12 * root.ui)
                    }
                }
            }
        }
    }
}
