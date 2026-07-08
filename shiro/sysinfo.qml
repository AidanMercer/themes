import QtQuick
import Quickshell
import Quickshell.Io

// shiro: margin notes. A small washi slip pinned bottom-right — system vitals
// written like a diary entry: tiny letterspaced labels, thin serif numerals,
// each meter a tapered ink brush stroke that lengthens with load. Per-core
// load is an ink spatter row; a hanko seal sits in the corner and the spine
// stroke down the left edge warms from wisteria to rose as the machine works.
// Hover-reveal: hidden until the bar's micro-meters are hovered or the
// Super+. pin flips (the shared flag-file contract). One bash poll every 3s
// while shown (pure builtins), a slow warm tick while hidden.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    readonly property color rose:     pal.magenta
    readonly property color amber:    pal.amber
    readonly property string sans:    "Noto Sans"
    readonly property string serif:   "Noto Serif Display"
    readonly property string mono:    pal.fontMono
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function tintA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function tone(v) { return v >= 90 ? rose : v >= 75 ? amber : wisteria }

    // ── live state ──────────────────────────────────────────────────────
    property int cpuPct: -1
    property var coreLoads: []
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
    property var _prevCore: ({})
    property real _prevRx: -1
    property real _prevTx: -1

    readonly property color health: tone(Math.max(cpuPct, memPct))

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // reveal contract: the bar's meters cluster writes the hover flag, the
    // shell's Super+. writes the pin flag; either raises the slip
    property bool hoverShown: false
    property bool pinShown: false
    readonly property bool shown: hoverShown || pinShown
    onShownChanged: if (shown) sway.restart()
    property real showT: shown ? 1 : 0
    Behavior on showT { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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

    // everything from /proc + /sys with bash builtins only — one fork per poll
    Process {
        id: statProc
        command: ["bash", "-c",
            'while read -r l; do case "$l" in cpu*) echo "S $l";; *) break;; esac; done </proc/stat; ' +
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
        const cores = []
        const nextCore = {}
        let memT = 0, memA = 0, rx = 0, tx = 0
        for (const line of raw.split("\n")) {
            const tag = line[0]
            const rest = line.slice(2)
            if (tag === "S") {
                const f = rest.trim().split(/\s+/)
                const key = f[0]
                const n = f.slice(1).map(Number)
                if (n.length < 5) continue
                const idle = n[3] + n[4]
                const total = n.reduce((a, b) => a + b, 0)
                if (key === "cpu") {
                    const dT = total - _prevTotal, dI = idle - _prevIdle
                    if (_prevTotal > 0 && dT > 0) cpuPct = Math.round(100 * (dT - dI) / dT)
                    _prevTotal = total; _prevIdle = idle
                } else {
                    const p = _prevCore[key]
                    if (p && total > p.t) cores.push(Math.round(100 * ((total - p.t) - (idle - p.i)) / (total - p.t)))
                    else cores.push(0)
                    nextCore[key] = { t: total, i: idle }
                }
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
        _prevCore = nextCore
        if (cores.length) coreLoads = cores
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
    // a tapered ink brush stroke over a hairline track, length = value
    component Brush: Canvas {
        id: brush
        property real value: 0            // 0..1
        property color tint: root.wisteria
        property real shown: 0
        width: parent ? parent.width : 0
        height: 8
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        onValueChanged: shown = Math.max(0, Math.min(1, value))
        onShownChanged: requestPaint()
        onTintChanged: requestPaint()
        onWidthChanged: requestPaint()
        property color inkRef: root.ink
        onInkRefChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cy = height / 2
            ctx.strokeStyle = root.inkA(0.10)
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(0, cy + 0.5); ctx.lineTo(width, cy + 0.5); ctx.stroke()
            const w = width * shown
            if (w < 1) return
            ctx.beginPath()
            ctx.moveTo(0, cy)
            for (let x = 0; x <= w; x += 3) {
                const t = x / width
                const th = 1.5 + 2.3 * Math.pow(1 - t, 1.3) + Math.sin(t * 9 + 1) * 0.4
                ctx.lineTo(x, cy - th / 2)
            }
            for (let x = w; x >= 0; x -= 3) {
                const t = x / width
                const th = 1.5 + 2.3 * Math.pow(1 - t, 1.3) + Math.sin(t * 9 + 1) * 0.4
                ctx.lineTo(x, cy + th / 2)
            }
            ctx.closePath()
            ctx.fillStyle = root.tintA(tint, 0.8)
            ctx.fill()
            // the flick where the brush lifted
            ctx.beginPath()
            ctx.arc(Math.min(width - 2, w + 2), cy - 2.4, 1.1, 0, Math.PI * 2)
            ctx.fillStyle = root.tintA(tint, 0.45)
            ctx.fill()
        }
    }

    // label · thin serif percentage
    component StatLine: Item {
        property string label: ""
        property int value: -1
        property color tint: root.ink
        width: parent ? parent.width : 0
        implicitHeight: 24

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            text: label
            color: root.inkA(0.45)
            font.family: root.sans
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
                color: root.ink
                font.family: root.serif
                font.pixelSize: 21
                font.weight: Font.Light
            }
            Text {
                anchors.baseline: num.baseline
                text: "%"
                color: root.inkA(0.40)
                font.family: root.sans
                font.pixelSize: 9
            }
        }
    }

    // ── the slip, pinned bottom-right ───────────────────────────────────
    Item {
        id: panel
        width: 224
        height: col.implicitHeight + 30
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 30
        anchors.bottomMargin: 30 - 12 * (1 - root.showT)
        opacity: root.bootT * root.showT
        visible: root.showT > 0.01
        scale: root.pal.uiScale
        transformOrigin: Item.BottomRight

        // set down like paper — one quiet rock, then still
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: -1.6; to: 0.5; duration: 550; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.5; to: 0; duration: 500; easing.type: Easing.OutSine }
        }

        // washi paper wash + ink hairline, crisp corners like the notif cards
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: Qt.rgba(1, 1, 1, 0.55)
            border.width: 1
            border.color: root.inkA(0.14)
        }

        // spine: tapered brush stroke down the left edge, health-toned
        Canvas {
            id: spine
            width: 10
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 5 }
            property color tint: root.health
            onTintChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const h = height
                if (h <= 0) return
                ctx.beginPath()
                ctx.moveTo(2, 0)
                for (let y = 0; y <= h; y += 4) {
                    const t = Math.min(1, y / h)
                    const w = 0.8 + 3.2 * Math.pow(1 - t, 1.4) + Math.sin(t * 8 + 1) * 0.5
                    ctx.lineTo(2 + Math.max(0.7, w), y)
                }
                ctx.lineTo(2, h)
                ctx.closePath()
                ctx.fillStyle = root.tintA(tint, 0.7)
                ctx.fill()
            }
        }

        // hanko seal, bottom-right — echoes the notification stamp
        Rectangle {
            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
            width: 9; height: 9; radius: 2
            color: "transparent"
            border.width: 1
            border.color: root.blush
            opacity: 0.4
            Rectangle {
                anchors.centerIn: parent
                width: 3; height: 3; radius: 1
                color: root.blush
            }
        }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 22
            anchors.rightMargin: 16
            anchors.topMargin: 14
            spacing: 8

            // header: s y s t e m + uptime as a diary date
            Item {
                width: parent.width
                height: 14
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "s y s t e m"
                    color: root.blush
                    font.family: root.sans
                    font.pixelSize: 10
                    font.letterSpacing: 4
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.uptimeText
                    color: root.inkA(0.45)
                    font.family: root.serif
                    font.pixelSize: 10
                    font.italic: true
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.10) }

            StatLine { label: "CPU"; value: root.cpuPct }
            Brush { value: root.cpuPct / 100; tint: root.tone(root.cpuPct) }

            // per-core ink spatter + temperature
            Item {
                width: parent.width
                height: 8
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: root.coreLoads
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4; height: 4; radius: 2
                            color: modelData >= 85 ? root.rose : root.ink
                            opacity: 0.12 + 0.6 * modelData / 100
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                        }
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.cpuTemp > 0
                    text: root.cpuTemp + "°"
                    color: root.inkA(0.40)
                    font.family: root.sans
                    font.pixelSize: 8
                }
            }

            StatLine { label: "MEMORY"; value: root.memPct }
            Brush { value: root.memPct / 100; tint: root.tone(root.memPct) }
            Text {
                anchors.right: parent.right
                text: root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(1) + " gb"
                color: root.inkA(0.38)
                font.family: root.sans
                font.pixelSize: 8
            }

            StatLine {
                visible: root.gpuPct >= 0
                height: root.gpuPct >= 0 ? implicitHeight : 0
                label: "GPU"; value: root.gpuPct
            }
            Brush {
                visible: root.gpuPct >= 0
                height: root.gpuPct >= 0 ? 8 : 0
                value: root.gpuPct / 100; tint: root.tone(root.gpuPct)
            }

            StatLine {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                label: "BATTERY"; value: root.batPct
            }
            Item {
                visible: root.hasBattery
                width: parent.width
                height: root.hasBattery ? 8 : 0
                Brush {
                    width: parent.width
                    value: root.batPct / 100
                    tint: root.batPct >= 0 && root.batPct < 20 ? root.rose : root.blush
                }
                // breathing blush dot while charging, like the clock's date dot
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.batCharging
                    width: 5; height: 5; radius: 2.5
                    color: root.blush
                    SequentialAnimation on opacity {
                        running: root.batCharging && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 2100; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2100; easing.type: Easing.InOutSine }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.10) }

            // footer: connection + rates
            Item {
                width: parent.width
                height: 14
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; radius: 2
                        color: root.online ? root.wisteria : root.rose
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName.toLowerCase() : "offline"
                        textFormat: Text.PlainText
                        color: root.inkA(0.55)
                        font.family: root.sans
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 120)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓ " + root.fmtRate(root.rxRate) + "  ↑ " + root.fmtRate(root.txRate)
                    color: root.inkA(0.40)
                    font.family: root.mono
                    font.pixelSize: 8
                }
            }
        }
    }
}
