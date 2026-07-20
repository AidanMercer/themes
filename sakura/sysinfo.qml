import QtQuick
import Quickshell
import Quickshell.Io

// sakura: the wish plaque. Hovering the bar's vitals (or Super+. pin) hangs a
// small wooden ema off the branch on two cords, top-right; it swings in and
// settles plumb (the hanging settle, law 3). Every subsystem is a row whose
// meter is a shelf of five blossoms — load opens them left to right, bud to
// bloom (law 1: numbers are bloom). Overheating rows blush rose. Sections with
// no source (no gpu, no battery) never grow. Reads /proc + nmcli itself;
// self-contained, click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color peach: pal.amber
    readonly property color twig:  pal.dim
    readonly property color cream: pal.text
    readonly property color plum:  pal.glass
    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function twigA(a)  { return Qt.rgba(twig.r, twig.g, twig.b, a) }
    function plumA(a)  { return Qt.rgba(plum.r, plum.g, plum.b, a) }

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

    function tone(v, w, c) { return v >= c ? rose : v >= w ? peach : pink }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 800; easing.type: Easing.OutSine }

    // hover reveal — the bar's vitals write "1"/"0" here while hovered
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 260; easing.type: Easing.OutSine } }
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

    // ── pollers — only while the plaque hangs (reveal refreshes instantly) ──
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

    // the notched-petal blossom painter — shared idiom
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.13), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    // ── a plaque row: label, five-blossom shelf, readout ────────────────────
    component ShelfRow: Item {
        id: row
        property string label: "cpu"
        property int value: -1        // 0..100, -1 = source missing
        property color tint: root.pink
        property string readout: ""
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: root.sans
            font.pixelSize: 11
            font.letterSpacing: 2
            color: root.creamA(0.88)
        }

        // the shelf: five blossoms opening left to right with the level
        Canvas {
            id: shelf
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.verticalCenter: parent.verticalCenter
            width: 110; height: 20
            readonly property real level: row.value < 0 ? 0 : row.value / 100
            onLevelChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const n = 5
                for (let i = 0; i < n; i++) {
                    // each blossom holds a fifth of the range
                    const local = Math.max(0, Math.min(1, shelf.level * n - i))
                    ctx.save()
                    ctx.translate(11 + i * 22, height / 2)
                    root.drawBlossom(ctx, 8.5, local,
                                     String(Qt.rgba(row.tint.r, row.tint.g, row.tint.b, local > 0 ? 0.45 + local * 0.5 : 0)),
                                     String(root.creamA(local > 0 ? 0.75 : 0)))
                    // empty stages still show as faint buds so the shelf reads as 5 slots
                    if (local <= 0) {
                        ctx.beginPath()
                        ctx.arc(0, 0, 2.4, 0, 2 * Math.PI)
                        ctx.fillStyle = String(root.twigA(0.7))
                        ctx.fill()
                    }
                    ctx.restore()
                }
            }
            Connections {
                target: root.pal
                function onNeonChanged() { shelf.requestPaint() }
                function onDimChanged() { shelf.requestPaint() }
            }
            Connections {
                target: row
                function onTintChanged() { shelf.requestPaint() }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.readout
            font.family: root.mono
            font.pixelSize: 10
            color: row.value >= 0 ? row.tint : root.creamA(0.5)
        }
    }

    // ── the plaque, hung on two cords from the bar ──────────────────────────
    Item {
        id: hanger
        width: 308
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 26
        anchors.topMargin: 0
        height: plaque.height + 40
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: pal.uiScale
        transformOrigin: Item.TopRight

        // it swings in on its cords and settles plumb
        transform: Rotation {
            id: swayRot
            origin.x: hanger.width / 2
            origin.y: 0
            angle: 0
        }
        SequentialAnimation {
            id: sway
            running: false
            NumberAnimation { target: swayRot; property: "angle"; from: -2.6; to: 1.2; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: swayRot; property: "angle"; from: 1.2; to: -0.5; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: swayRot; property: "angle"; from: -0.5; to: 0; duration: 500; easing.type: Easing.OutSine }
        }

        // the two cords
        Rectangle { x: 40; y: -2 - 8 * (1 - root.showT); width: 1.2; height: 42; color: root.twigA(0.9); rotation: 6 }
        Rectangle { x: hanger.width - 40; y: -2 - 8 * (1 - root.showT); width: 1.2; height: 42; color: root.twigA(0.9); rotation: -6 }

        Rectangle {
            id: plaque
            width: parent.width
            height: col.implicitHeight + 30
            y: 38 - 10 * (1 - root.showT)
            radius: 12
            color: root.plumA(0.88)
            border.width: 1
            border.color: root.pinkA(0.38)

            // pink light along the top edge, like sun through the canopy
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 40
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.pinkA(0.10) }
                    GradientStop { position: 1.0; color: root.pinkA(0.0) }
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

                // header: the plaque's inscription
                Item {
                    width: parent.width
                    height: 20
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Canvas {
                            id: headBlossom
                            width: 15; height: 15
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.translate(width / 2, height / 2)
                                root.drawBlossom(ctx, 7, 1, String(root.pinkA(0.92)), String(root.creamA(0.9)))
                            }
                            Component.onCompleted: requestPaint()
                            Connections {
                                target: root.pal
                                function onNeonChanged() { headBlossom.requestPaint() }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "the wish plaque"
                            font.family: root.sans
                            font.pixelSize: 13
                            font.letterSpacing: 2
                            color: root.creamA(0.95)
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "hanami"
                        font.family: root.sans
                        font.italic: true
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        color: root.pinkA(0.7)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.twigA(0.6) }

                ShelfRow {
                    label: "cpu"
                    value: root.cpuPercent
                    tint: root.tone(root.cpuPercent, 60, 85)
                    readout: root.cpuPercent < 0 ? "--"
                        : root.cpuPercent + "%" + (root.cpuTemp > 0 ? " " + root.cpuTemp + "°" : "")
                }
                ShelfRow {
                    label: "mem"
                    value: root.ramPercent
                    tint: root.tone(root.ramPercent, 70, 90)
                    readout: root.ramPercent < 0 ? "--"
                        : root.ramUsedGb.toFixed(1) + "/" + root.ramTotalGb.toFixed(0) + "G"
                }
                ShelfRow {
                    visible: root.hasGpu
                    height: root.hasGpu ? 30 : 0
                    label: "gpu"
                    value: root.gpuPercent
                    tint: root.tone(root.gpuPercent, 60, 85)
                    readout: root.gpuPercent + "% " + root.gpuTemp + "°"
                }
                ShelfRow {
                    visible: root.hasBattery
                    height: root.hasBattery ? 30 : 0
                    label: "power"
                    value: root.batteryPercent
                    tint: root.batteryCharging ? root.peach
                        : root.batteryPercent <= 15 ? root.rose
                        : root.batteryPercent <= 30 ? root.peach : root.pink
                    readout: (root.batteryCharging ? "↑ " : "") + root.batteryPercent + "%"
                }

                // net: name left, rates right
                Item {
                    width: parent.width
                    height: 24
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(root.online ? (root.connType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
                            font.family: root.icon
                            font.pixelSize: 11
                            color: root.online ? root.sky : root.rose
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? root.connName : "offline"
                            textFormat: Text.PlainText
                            font.family: root.mono
                            font.pixelSize: 10
                            color: root.online ? root.creamA(0.82) : root.rose
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                        font.family: root.mono
                        font.pixelSize: 10
                        color: root.creamA(0.7)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.twigA(0.6) }

                // foot: how long the afternoon has been held
                Item {
                    width: parent.width
                    height: 18
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "afternoon held " + root.uptimeText
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: root.creamA(0.7)
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "❀ sakura"
                        font.family: root.sans
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        color: root.pinkA(0.65)
                    }
                }
            }
        }
    }
}
