import QtQuick
import Quickshell
import Quickshell.Io

// avalon: the ledger of small offerings. A votive tablet hanging from a gold
// cord at the top-right, over the dark trees — vitals written in serif cream
// on pond-dark glass. Each meter is a gold hairline with a diamond bead that
// slides with load; a five-petal blossom in the header lights petal by petal
// as the CPU works. A radial moss scrim sits behind the tablet so the text
// survives the bright parts of the video (the theme's legibility trick).
// Hover-reveal: the tablet gets hung up when the bar's vitals are hovered or
// the Super+. pin flips (the shared flag-file contract), swaying as it
// settles. One bash poll every 3s while shown, a slow warm tick while hidden.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color cream: pal.text
    readonly property color leaf:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rust:  pal.magenta
    readonly property color hay:   pal.amber
    readonly property color sage:  pal.dim
    readonly property color pond:  pal.glass
    readonly property string mono:  pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function tintA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function tone(v) { return v >= 90 ? rust : v >= 75 ? hay : leaf }

    // ── live state ──────────────────────────────────────────────────────
    property int cpuPct: -1
    property int cpuTemp: -1
    property int memPct: -1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property int gpuPct: -1
    property int gpuTries: 0
    property int batPct: -1
    property bool batCharging: false
    property bool hasBattery: false
    property bool online: false
    property string connName: ""
    property string uptimeText: "—"
    property real rxRate: 0
    property real txRate: 0

    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _prevRx: -1
    property real _prevTx: -1

    // reveal contract: the bar's vitals cluster writes the hover flag, the
    // shell's Super+. writes the pin flag; either hangs the tablet up
    property bool hoverShown: false
    property bool pinShown: false
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView {
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
    FileView {
        id: pinFlag
        path: root.pinFlagPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.pinShown = pinFlag.text().trim() === "1"
    }

    // ── pollers — fast while shown, a slow warm tick while hidden ───────
    Timer {
        interval: root.shown ? 3000 : 30000
        running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: statProc.running = true
    }
    Timer {
        interval: root.shown ? 10000 : 60000
        running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: slowProc.running = true
    }

    Process {
        id: statProc
        command: ["bash", "-c",
            'read -r l </proc/stat; echo "S $l"; ' +
            'while read -r k v _; do case "$k" in MemTotal:|MemAvailable:) echo "M $k $v";; esac; done </proc/meminfo; ' +
            'read -r up _ </proc/uptime; echo "U $up"; ' +
            'for b in /sys/class/power_supply/BAT*/capacity; do [ -r "$b" ] && { read -r c <"$b"; read -r s <"${b%capacity}status"; echo "B $c $s"; break; }; done; ' +
            'for h in /sys/class/hwmon/hwmon*/name; do read -r n <"$h"; case "$n" in coretemp|k10temp|zenpower) read -r t <"${h%name}temp1_input" && echo "T $t"; break;; esac; done 2>/dev/null; ' +
            'while read -r l; do case "$l" in *:*) echo "D $l";; esac; done </proc/net/dev; true']
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Process {
        id: slowProc
        command: ["bash", "-c",
            'if [ "$1" = probe ]; then ' +
            '  if command -v nvidia-smi >/dev/null 2>&1; then o=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); [ -n "$o" ] && echo "G $o"; fi; ' +
            '  if ! command -v nvidia-smi >/dev/null 2>&1 || [ -z "$o" ]; then for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && { read -r v <"$f"; echo "G $v"; break; }; done; fi; ' +
            'fi; ' +
            'echo "C $(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ":loopback\\|:bridge\\|:tun" | head -1)"; true',
            "_", (root.gpuPct >= 0 || root.gpuTries < 3) ? "probe" : "skip"]
        stdout: StdioCollector { onStreamFinished: root.parseSlow(text) }
    }

    function parseStats(raw) {
        let memT = 0, memA = 0, rx = 0, tx = 0
        for (const line of raw.split("\n")) {
            const tag = line[0]
            const rest = line.slice(2)
            if (tag === "S") {
                const n = rest.trim().split(/\s+/).slice(1).map(Number)
                if (n.length < 5) continue
                const idle = n[3] + n[4]
                const total = n.reduce((a, b) => a + b, 0)
                const dT = total - _prevTotal, dI = idle - _prevIdle
                if (_prevTotal > 0 && dT > 0) cpuPct = Math.round(100 * (dT - dI) / dT)
                _prevTotal = total; _prevIdle = idle
            } else if (tag === "M") {
                if (rest.indexOf("MemTotal") === 0) memT = parseInt(rest.split(/\s+/)[1])
                else memA = parseInt(rest.split(/\s+/)[1])
            } else if (tag === "U") {
                let s = Math.floor(parseFloat(rest) || 0)
                const d = Math.floor(s / 86400); s -= d * 86400
                const h = Math.floor(s / 3600); const m = Math.floor((s % 3600) / 60)
                uptimeText = d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
            } else if (tag === "B") {
                const f = rest.trim().split(/\s+/)
                const c = parseInt(f[0])
                if (!isNaN(c)) { hasBattery = true; batPct = c; batCharging = f[1] === "Charging" }
            } else if (tag === "T") {
                const v = parseInt(rest)
                cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
            } else if (tag === "D") {
                const i = rest.indexOf(":")
                if (i < 0 || rest.slice(0, i).trim() === "lo") continue
                const f = rest.slice(i + 1).trim().split(/\s+/).map(Number)
                rx += f[0] || 0; tx += f[8] || 0
            }
        }
        if (memT > 0) {
            memPct = Math.round(100 * (memT - memA) / memT)
            memTotalGb = memT / 1048576
            memUsedGb = (memT - memA) / 1048576
        }
        if (_prevRx >= 0) {
            rxRate = Math.max(0, (rx - _prevRx) / 3)
            txRate = Math.max(0, (tx - _prevTx) / 3)
        }
        _prevRx = rx; _prevTx = tx
    }

    function parseSlow(raw) {
        let sawGpu = false
        for (const line of raw.split("\n")) {
            if (line[0] === "G") {
                const v = parseInt(line.slice(2))
                if (!isNaN(v)) { gpuPct = v; sawGpu = true }
            } else if (line[0] === "C") {
                const rest = line.slice(2).trim()
                if (!rest) { online = false; connName = "" }
                else {
                    const i = rest.lastIndexOf(":")
                    connName = i > 0 ? rest.slice(0, i) : rest
                    online = true
                }
            }
        }
        if (!sawGpu && gpuPct < 0) gpuTries++
    }

    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + "m" : Math.round(b / 1024) + "k"
    }

    // ── reusable bits ───────────────────────────────────────────────────
    // gold hairline meter with a diamond bead riding the fill
    component Bead: Item {
        id: bead
        property real value: 0            // 0..1
        property color tint: root.leaf
        width: parent ? parent.width : 0
        height: 9

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: root.goldA(0.25)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(1, bead.value)) * parent.width
            height: 2; radius: 1
            color: root.tintA(bead.tint, 0.85)
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, bead.value)) * (parent.width - 7)
            width: 7; height: 7
            rotation: 45
            color: root.pond
            border.width: 1
            border.color: bead.tint
            Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
    }

    // label · serif value line
    component Vital: Item {
        property string label: ""
        property int value: -1
        width: parent ? parent.width : 0
        implicitHeight: 22

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: label
            color: root.tintA(root.sage, 0.9)
            font.family: root.mono
            font.pixelSize: 9
            font.letterSpacing: 3
        }
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 2
            Text {
                id: num
                text: value < 0 ? "—" : String(value)
                color: root.cream
                font.family: root.serif
                font.pixelSize: 19
                font.weight: Font.Light
            }
            Text {
                anchors.baseline: num.baseline
                text: "%"
                color: root.creamA(0.45)
                font.family: root.serif
                font.pixelSize: 10
            }
        }
    }

    // ── the tablet, hanging top-right ───────────────────────────────────
    Item {
        id: hang
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.055)
        anchors.top: parent.top
        width: 236
        height: cord.height + tablet.height
        opacity: root.showT
        visible: root.showT > 0.01
        scale: root.pal.uiScale
        transformOrigin: Item.TopRight

        // the cord draws down first
        Rectangle {
            id: cord
            anchors.horizontalCenter: parent.horizontalCenter
            width: 1
            height: 44 * Math.min(1, root.showT * 1.6)
            color: root.goldA(0.55)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: cord.height - 3
            width: 5; height: 5
            rotation: 45
            color: root.gold
            opacity: 0.8
        }

        Item {
            id: tablet
            anchors.top: cord.bottom
            width: parent.width
            height: col.implicitHeight + 32

            // the tablet settles like something just hung up, replayed per reveal
            transformOrigin: Item.Top
            rotation: 0
            SequentialAnimation on rotation {
                id: sway
                running: false
                NumberAnimation { from: -2.2; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.0; to: -0.4; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { from: -0.4; to: 0; duration: 500; easing.type: Easing.OutSine }
            }

            // radial moss scrim so the ledger reads over bright video
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 1.7
                height: parent.height * 1.5
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width / 2, height / 2, 0,
                                                       width / 2, height / 2, width / 2)
                    g.addColorStop(0, Qt.rgba(root.pond.r, root.pond.g, root.pond.b, 0.5))
                    g.addColorStop(1, Qt.rgba(root.pond.r, root.pond.g, root.pond.b, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: root.tintA(root.pond, 0.72)
                border.width: 1
                border.color: root.goldA(0.35)
            }
            // gold seam under the top edge
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 5
                height: 1
                color: root.goldA(0.3)
            }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                spacing: 9

                // header: blossom that lights with load + vitals + uptime
                Item {
                    width: parent.width
                    height: 20

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Canvas {
                            id: blossom
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            property int lit: root.cpuPct < 0 ? 0 : Math.min(5, Math.ceil(root.cpuPct / 20))
                            onLitChanged: requestPaint()
                            Connections {
                                target: root.pal
                                function onNeonChanged() { blossom.requestPaint() }
                            }
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                const cx = width / 2, cy = height / 2
                                for (let i = 0; i < 5; i++) {
                                    const a = -Math.PI / 2 + i * 2 * Math.PI / 5
                                    const px = cx + Math.cos(a) * 5.2
                                    const py = cy + Math.sin(a) * 5.2
                                    ctx.beginPath()
                                    ctx.ellipse(px - 3.1, py - 3.1, 6.2, 6.2)
                                    if (i < lit) {
                                        ctx.fillStyle = root.tintA(root.leaf, 0.9)
                                        ctx.fill()
                                    } else {
                                        ctx.strokeStyle = root.tintA(root.sage, 0.9)
                                        ctx.lineWidth = 1
                                        ctx.stroke()
                                    }
                                }
                                ctx.beginPath()
                                ctx.ellipse(cx - 1.5, cy - 1.5, 3, 3)
                                ctx.fillStyle = root.gold
                                ctx.fill()
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "vitals"
                            color: root.creamA(0.9)
                            font.family: root.serif
                            font.pixelSize: 14
                            font.italic: true
                            font.letterSpacing: 2
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.uptimeText.toUpperCase()
                        color: root.tintA(root.sage, 0.95)
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 2
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.goldA(0.2) }

                Vital { label: "CPU"; value: root.cpuPct }
                Bead { value: root.cpuPct / 100; tint: root.tone(root.cpuPct) }
                // no height gymnastics — Column skips invisible children
                Text {
                    visible: root.cpuTemp > 0
                    anchors.right: parent.right
                    text: root.cpuTemp + "°c"
                    color: root.tintA(root.sage, 0.9)
                    font.family: root.mono
                    font.pixelSize: 8
                }

                Vital { label: "MEM"; value: root.memPct }
                Bead { value: root.memPct / 100; tint: root.tone(root.memPct) }
                Text {
                    anchors.right: parent.right
                    text: root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(1) + " gb"
                    color: root.tintA(root.sage, 0.9)
                    font.family: root.mono
                    font.pixelSize: 8
                }

                Vital {
                    visible: root.gpuPct >= 0
                    height: root.gpuPct >= 0 ? implicitHeight : 0
                    label: "GPU"; value: root.gpuPct
                }
                Bead {
                    visible: root.gpuPct >= 0
                    height: root.gpuPct >= 0 ? 9 : 0
                    value: root.gpuPct / 100; tint: root.tone(root.gpuPct)
                }

                Vital {
                    visible: root.hasBattery
                    height: root.hasBattery ? implicitHeight : 0
                    label: "PWR"; value: root.batPct
                }
                Item {
                    visible: root.hasBattery
                    width: parent.width
                    height: root.hasBattery ? 9 : 0
                    Bead {
                        width: parent.width
                        value: root.batPct / 100
                        tint: root.batPct >= 0 && root.batPct < 20 ? root.rust : root.gold
                    }
                    // a buttercup firefly breathing while it charges
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: -9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.batCharging
                        width: 4; height: 4; radius: 2
                        color: root.gold
                        SequentialAnimation on opacity {
                            running: root.batCharging && root.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 1800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.goldA(0.2) }

                // net + rates
                Item {
                    width: parent.width
                    height: 13
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4; height: 4
                            rotation: 45
                            color: root.online ? root.leaf : root.rust
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.online ? root.connName.toLowerCase() : "offline"
                            textFormat: Text.PlainText
                            color: root.creamA(0.6)
                            font.family: root.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 118)
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                        color: root.tintA(root.sage, 0.95)
                        font.family: root.mono
                        font.pixelSize: 8
                    }
                }

                // the whisper
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "where the small gods sleep"
                    color: root.tintA(root.sage, 0.85)
                    font.family: root.serif
                    font.pixelSize: 10
                    font.italic: true
                    font.letterSpacing: 1
                }
            }
        }
    }
}
