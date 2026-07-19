import QtQuick
import Quickshell
import Quickshell.Io

// stillwater: SOUNDINGS. Hover the sounding lead in the bar (or pin with
// Super+.) and a small survey card surfaces out of the bar's waterline,
// bottom-right — rising like something buoyant and settling with a slow
// float-tilt, the way a light craft takes the water. Each measure of the
// machine is a strand of lamps on a line: CURRENT is the CPU, DEPTH memory,
// GLOW the GPU, RESERVE the battery, FAR SHORE the network — lamps light
// warm-white, run lantern-halo when pressed, dusk-rose when critical, and
// every strand is doubled beneath itself as a dim broken streak, per the
// house law. The card itself stands on its own waterline at its foot.
// Sections with no source never light. Reads /proc + nmcli itself; polls
// only while revealed; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    readonly property color halo: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
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

    function tone(v, w, c) { return v >= c ? rose : v >= w ? halo : lamp }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // hover reveal — the bar's sounding lead writes "1"/"0" here while hovered
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 320; easing.type: Easing.InOutSine } }
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

    // ── pollers — only while the card is actually up ────────────────────────
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

    // ── a strand of lamps: the house meter ──────────────────────────────────
    component Strand: Item {
        id: row
        property string label: "CURRENT"
        property int value: -1        // 0..100, -1 leaves the strand dark
        property color tone: root.lamp
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            y: 2
            text: row.label
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 3
            color: root.inkA(0.8)
        }
        // the strand and its double
        Item {
            anchors.left: parent.left
            anchors.leftMargin: 96
            y: 6
            width: 14 * 11
            height: 12
            Row {
                spacing: 6
                Repeater {
                    model: 14
                    delegate: Rectangle {
                        required property int index
                        readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 100 * 14)
                        width: 5; height: 5
                        radius: 2.5
                        color: lit ? row.tone : "transparent"
                        border.width: 1
                        border.color: lit ? row.tone : root.slateA(0.55)
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
            // the streak beneath the strand — dimmer, broken
            Row {
                y: 8
                spacing: 6
                Repeater {
                    model: 14
                    delegate: Rectangle {
                        required property int index
                        readonly property bool lit: row.value >= 0 && index < Math.round(row.value / 100 * 14)
                        width: 5; height: 2
                        color: lit ? Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.22) : "transparent"
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right
            y: 2
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tone : root.slateA(1.0)
        }
    }

    // ── the card, surfacing bottom-right above the bar ──────────────────────
    Item {
        id: card
        width: 330
        height: face.height
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 60 + 16 * root.showT
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.BottomRight

        // buoyancy: the card takes the water, tilts, and settles level
        transform: Rotation {
            id: swayR
            origin.x: card.width / 2
            origin.y: card.height
            angle: 0
        }
        SequentialAnimation {
            id: sway
            running: false
            NumberAnimation { target: swayR; property: "angle"; from: -1.6; to: 1.0; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { target: swayR; property: "angle"; from: 1.0; to: -0.5; duration: 540; easing.type: Easing.InOutSine }
            NumberAnimation { target: swayR; property: "angle"; from: -0.5; to: 0; duration: 460; easing.type: Easing.OutSine }
        }

        Rectangle {
            id: face
            width: parent.width
            height: col.implicitHeight + 34
            radius: 10
            color: root.glassA(0.90)
            border.width: 1
            border.color: root.skyA(0.30)
            // dusk glow pooling at the top of the glass
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 40
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.rose.r, root.rose.g, root.rose.b, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 16
            spacing: 5

            // header: a lamp on the line + the survey's name
            Item {
                width: parent.width
                height: 20
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5
                        radius: 2.5
                        color: root.lamp
                        SequentialAnimation on opacity {
                            running: root.shown && !root.occluded
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SOUNDINGS"
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 5
                        color: root.lamp
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "STILL WATER"
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 3
                    color: root.slateA(1.0)
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.skyA(0.18) }

            Strand {
                label: "CURRENT"
                value: root.cpuPercent
                tone: root.tone(root.cpuPercent, 60, 85)
                readout: root.cpuPercent < 0 ? "--"
                    : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
            }
            Strand {
                label: "DEPTH"
                value: root.ramPercent
                tone: root.tone(root.ramPercent, 70, 90)
                readout: root.ramPercent < 0 ? "--"
                    : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
            }
            Strand {
                visible: root.hasGpu
                height: root.hasGpu ? 30 : 0
                label: "GLOW"
                value: root.gpuPercent
                tone: root.tone(root.gpuPercent, 60, 85)
                readout: root.gpuPercent + "% " + root.gpuTemp + "°"
            }
            Strand {
                visible: root.hasBattery
                height: root.hasBattery ? 30 : 0
                label: "RESERVE"
                value: root.batteryPercent
                tone: root.batteryCharging ? root.sky
                    : root.batteryPercent <= 15 ? root.rose
                    : root.batteryPercent <= 30 ? root.halo : root.lamp
                readout: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
            }

            // FAR SHORE is text-only: connection left, rates right
            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FAR SHORE"
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 3
                        color: root.inkA(0.8)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4
                        radius: 2
                        color: root.online ? root.lamp : root.rose
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName : "dark"
                        textFormat: Text.PlainText
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.online ? root.inkA(0.75) : root.rose
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

            // the card's own waterline, and its footing in the water
            Rectangle { width: parent.width; height: 1; color: root.skyA(0.22) }
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    spacing: 4
                    y: 2
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 10 - index * 3; height: 2
                            color: root.skyA(0.25 - index * 0.07)
                        }
                    }
                }
                Text {
                    anchors.right: parent.right
                    y: 1
                    text: "the evening, " + root.uptimeText + " in"
                    font.family: root.mono
                    font.pixelSize: 9
                    color: root.inkA(0.45)
                }
            }
        }
    }
}
