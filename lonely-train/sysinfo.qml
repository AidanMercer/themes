import QtQuick
import Quickshell
import Quickshell.Io

// lonely-train: the arrivals board. A station placard bottom-right where each
// subsystem runs as a service line — a dusk route with five station dots, an
// amber fill riding to the current load and a status word (ON TIME / BUSY /
// DELAYED) on the right. The CPU line pulls a consist of tiny lit cars, one
// per core. Amber band + LT roundel keep the station-sign grammar; the footer
// whisper answers the clock's "bound for home".
// Hover-reveal: lights up when the bar's guard panel is hovered or the
// Super+. pin flips (the shared flag-file contract). One bash poll every 3s
// while shown (pure builtins), a slow warm tick while hidden.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color warn:  pal.amber
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property string mono:  pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

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
    property string svcText: "000:00"
    property real rxRate: 0
    property real txRate: 0

    property real _prevTotal: 0
    property real _prevIdle: 0
    property var _prevCore: ({})
    property real _prevRx: -1
    property real _prevTx: -1

    readonly property bool anyLate: cpuPct >= 85 || memPct >= 90 || gpuPct >= 90

    // reveal contract: the bar's guard panel writes the hover flag, the
    // shell's Super+. writes the pin flag; either lights the board
    property bool hoverShown: false
    property bool pinShown: false
    property bool occluded: false   // loader writes true while the session is locked
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

    // ── pollers ─────────────────────────────────────────────────────────
    // poll only while the card is actually up (reveal refreshes instantly via triggeredOnStart)
    Timer {
        interval: 3000
        running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: statProc.running = true
    }
    Timer {
        interval: 10000
        running: root.shown && !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: slowProc.running = true
    }

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
            '  if [ -d /sys/module/nvidia ] && command -v nvidia-smi >/dev/null 2>&1; then o=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); [ -n "$o" ] && echo "G $o"; fi; ' +
            '  if [ -z "$o" ]; then for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && { read -r v <"$f"; echo "G $v"; break; }; done; fi; ' +
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
                const s = Math.floor(parseFloat(rest) || 0)
                const h = Math.floor(s / 3600)
                const m = Math.floor((s % 3600) / 60)
                svcText = String(h).padStart(3, "0") + ":" + String(m).padStart(2, "0")
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
    function statusWord(v) {
        return v < 0 ? "—" : v >= 85 ? "DELAYED" : v >= 60 ? "BUSY" : "ON TIME"
    }
    function statusTint(v) {
        return v >= 85 ? tail : v >= 60 ? warn : duskA(0.85)
    }

    // ── a service line: label, route meter with stations, value + status ──
    component ServiceRow: Item {
        id: row
        property string label: ""
        property int value: -1
        property string status: root.statusWord(value)
        property color statusCol: root.statusTint(value)
        width: parent ? parent.width : 0
        implicitHeight: 30

        Text {
            id: lbl
            anchors.left: parent.left
            anchors.top: parent.top
            text: label
            color: root.duskA(0.7)
            font.family: root.mono
            font.pixelSize: 9
            font.letterSpacing: 3
        }
        // the route: dusk track, amber fill riding to the load, five stations
        Item {
            anchors.left: parent.left
            anchors.right: valueCol.left
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            height: 7

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1.5
                color: root.duskA(0.3)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(1, row.value / 100)) * parent.width
                height: 1.5
                color: root.amberA(0.9)
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    x: index / 4 * (parent.width - width)
                    width: 5; height: 5; radius: 2.5
                    readonly property bool passed: row.value >= 0 && row.value / 100 >= index / 4 && row.value > 0
                    color: passed ? root.amber : root.glass
                    border.width: 1
                    border.color: passed ? root.amber : root.duskA(0.6)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
        Column {
            id: valueCol
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                anchors.right: parent.right
                text: row.value < 0 ? "—" : row.value + "%"
                color: root.inkA(0.92)
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                text: row.status
                color: row.statusCol
                font.family: root.mono
                font.pixelSize: 7
                font.letterSpacing: 2
            }
        }
    }

    // ── the placard, bottom-right above the bar ─────────────────────────
    Item {
        id: board
        width: 268
        height: col.implicitHeight + 30
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.045)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.10) - 10 * (1 - root.showT)
        opacity: root.showT
        visible: root.showT > 0.01
        scale: root.pal.uiScale
        transformOrigin: Item.BottomRight

        // the station placard tips as it's hung, steadies on its bracket
        SequentialAnimation on rotation {
            id: sway
            running: false
            NumberAnimation { from: 2.2; to: -0.9; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { from: -0.9; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.35; to: 0; duration: 400; easing.type: Easing.OutSine }
        }

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: root.glassA(0.88)
            border.width: 1
            border.color: root.inkA(0.12)
        }
        // amber band along the top edge — station-sign grammar
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 2
            radius: 1
            color: root.amberA(0.8)
        }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 14
            spacing: 9

            // header: roundel + ARRIVALS + service counter
            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8
                        color: "transparent"
                        border.width: 1.5
                        border.color: root.amber
                        Text {
                            anchors.centerIn: parent
                            text: "LT"
                            color: root.amber
                            font.family: root.mono
                            font.pixelSize: 6
                            font.weight: Font.Black
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ARRIVALS"
                        color: root.amberA(0.92)
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 5
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; radius: 2
                        color: root.tail
                        opacity: 0.8
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SVC " + root.svcText
                        color: root.inkA(0.45)
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.12) }

            ServiceRow { label: "CPU"; value: root.cpuPct }

            // the consist: one lit car per core
            Item {
                width: parent.width
                height: 6
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: root.coreLoads
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9; height: 4; radius: 1.5
                            color: modelData >= 85 ? root.tail : root.amber
                            opacity: 0.10 + 0.7 * modelData / 100
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4; height: 1
                                color: Qt.rgba(0, 0, 0, 0.5)
                            }
                        }
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.cpuTemp > 0
                    text: root.cpuTemp + "°C"
                    color: root.inkA(0.4)
                    font.family: root.mono
                    font.pixelSize: 7
                    font.letterSpacing: 1
                }
            }

            ServiceRow { label: "MEM"; value: root.memPct }
            Text {
                anchors.right: parent.right
                text: root.memUsedGb.toFixed(1) + " / " + root.memTotalGb.toFixed(1) + " GB"
                color: root.inkA(0.4)
                font.family: root.mono
                font.pixelSize: 7
                font.letterSpacing: 1
            }

            ServiceRow {
                visible: root.gpuPct >= 0
                height: root.gpuPct >= 0 ? implicitHeight : 0
                label: "GPU"; value: root.gpuPct
            }

            ServiceRow {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                label: "PWR"; value: root.batPct
                status: root.batCharging ? "BOARDING"
                    : root.batPct >= 0 && root.batPct < 20 ? "LAST CALL" : "ON TIME"
                statusCol: root.batCharging ? root.amber
                    : root.batPct >= 0 && root.batPct < 20 ? root.tail : root.duskA(0.85)
            }

            Rectangle { width: parent.width; height: 1; color: root.inkA(0.12) }

            // footer: connection + rates, then the whisper
            Item {
                width: parent.width
                height: 12
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: root.online ? "transparent" : root.tail
                        border.width: 1.5
                        border.color: root.online ? root.dusk : root.tail
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.online ? root.connName.toUpperCase() : "NO SERVICE"
                        textFormat: Text.PlainText
                        color: root.online ? root.duskA(0.85) : root.tail
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 130)
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    color: root.inkA(0.4)
                    font.family: root.mono
                    font.pixelSize: 8
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.anyLate ? "running a little late tonight" : "running on time tonight"
                color: root.inkA(0.55)
                font.family: root.serif
                font.pixelSize: 11
                font.italic: true
                font.letterSpacing: 1
            }
        }
    }
}
