import QtQuick
import Quickshell.Io

// vinland: a quiet ledger of vitals, bottom-right over the blurred grass.
// Plain header between carved staves, thin snow meters filled with ice.
// Sections whose source is missing (battery on the desktop) hide.
Item {
    id: root
    anchors.fill: parent

    // always-on readout: desktop scenery, not a popup — the loader parks this
    // under windows on the Bottom layer instead of floating it over them
    readonly property bool desktopSysinfo: true

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color amber: pal.amber
    readonly property real ui: pal.uiScale
    readonly property string sans: "Noto Sans"
    function snowA(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1000; easing.type: Easing.OutCubic }

    // night scrim so the ledger reads over the pale snow
    Canvas {
        id: scrim
        x: col.x + col.width / 2 - width / 2
        y: col.y + col.height / 2 - height / 2
        width: col.width * 2.4
        height: col.height * 2.6
        opacity: root.bootT
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = ctx.createRadialGradient(width / 2, height / 2, 0,
                                               width / 2, height / 2, Math.min(width, height) / 2)
            g.addColorStop(0, Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.58))
            g.addColorStop(1, Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
        Connections {
            target: root.pal
            function onGlassChanged() { scrim.requestPaint() }
        }
    }

    Column {
        id: col
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.045)
        y: Math.round(root.height * 0.70)
        spacing: 10
        opacity: root.bootT
        transform: Translate { x: 10 * (1 - root.bootT) }
        scale: root.ui
        transformOrigin: Item.TopRight

        Row {
            anchors.right: parent.right
            spacing: 8
            Rectangle {
                width: 26; height: 1
                color: root.iceA(0.50)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "system"
                color: root.iceA(0.90)
                font.family: root.sans
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 3
            }
            Rectangle {
                width: 26; height: 1
                color: root.iceA(0.50)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        VitalRow { label: "cpu"; value: root.cpuPct; detail: root.cpuTemp > 0 ? root.cpuTemp + "°" : Math.round(root.cpuPct * 100) + "%" }
        VitalRow { label: "mem"; value: root.memPct; detail: Math.round(root.memPct * 100) + "%" }

        Row {
            anchors.right: parent.right
            spacing: 9
            Text {
                text: "net"
                color: root.iceA(0.88)
                font.family: root.sans
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "↓ " + root.fmtRate(root.rxRate)
                color: root.snowA(0.80)
                font.family: pal.fontMono
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "↑ " + root.fmtRate(root.txRate)
                color: root.snowA(0.60)
                font.family: pal.fontMono
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        VitalRow {
            visible: root.batPct >= 0
            label: "bat"
            value: Math.max(0, root.batPct) / 100
            warn: false
            fill: root.batPct >= 0 && root.batPct < 20 && !root.batCharging ? root.rose
                : root.batCharging ? root.gold : root.ice
            detail: root.batPct + "%" + (root.batCharging ? "+" : "")
        }
    }

    component VitalRow: Row {
        property string label: ""
        property real value: 0
        property string detail: ""
        property bool warn: true
        property color fill: root.ice
        anchors.right: parent.right
        spacing: 9

        Text {
            text: parent.label
            color: root.iceA(0.88)
            font.family: root.sans
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            width: 74; height: 3
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.fill: parent; radius: 1.5; color: root.snowA(0.20) }
            Rectangle {
                width: Math.max(2, parent.width * Math.min(1, parent.parent.value))
                height: parent.height
                radius: 1.5
                color: parent.parent.warn && parent.parent.value > 0.9 ? root.rose
                     : parent.parent.warn && parent.parent.value > 0.75 ? root.amber
                     : parent.parent.fill
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
        Text {
            text: parent.detail
            color: root.snowA(0.75)
            font.family: pal.fontMono
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── data ─────────────────────────────────────────────────────────────────
    // pushed live by the loader: true while the session is locked → stop polling
    property bool occluded: false
    property real cpuPct: 0
    property int cpuTemp: -1
    property real memPct: 0
    property int batPct: -1
    property bool batCharging: false
    property real rxRate: 0
    property real txRate: 0
    property var _prevCpu: null
    property var _prevNet: null

    function fmtRate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps >= 1024) return Math.round(bps / 1024) + "K"
        return Math.round(bps) + "B"
    }

    function parseStats(out) {
        let memT = 0, memA = 0, rx = 0, tx = 0
        for (const raw of out.trim().split("\n")) {
            const l = raw.trim()
            if (l.startsWith("cpu ")) {
                const f = l.split(/\s+/).slice(1).map(Number)
                const tot = f.reduce((a, b) => a + b, 0)
                const idle = f[3] + (f[4] || 0)
                if (root._prevCpu) {
                    const dt = tot - root._prevCpu.tot, di = idle - root._prevCpu.idle
                    if (dt > 0) root.cpuPct = Math.max(0, Math.min(1, (dt - di) / dt))
                }
                root._prevCpu = { tot: tot, idle: idle }
            } else if (l.startsWith("MemTotal")) memT = parseInt(l.split(/\s+/)[1])
            else if (l.startsWith("MemAvailable")) memA = parseInt(l.split(/\s+/)[1])
            else if (l.startsWith("temp:")) {
                const v = parseInt(l.slice(5))
                root.cpuTemp = isNaN(v) || v <= 0 ? -1 : Math.round(v / 1000)
            } else if (l.indexOf(":") > 0 && !l.startsWith("lo:")) {
                // /proc/net/dev row — split on the colon, the counters can glue to it
                const f = l.split(":")[1].trim().split(/\s+/)
                if (f.length > 8) { rx += parseInt(f[0]) || 0; tx += parseInt(f[8]) || 0 }
            }
            else if (/^[0-9]+$/.test(l)) root.batPct = parseInt(l)
            else if (/^(Charging|Discharging|Full|Not charging)$/.test(l)) root.batCharging = l === "Charging"
        }
        if (memT > 0) root.memPct = Math.max(0, Math.min(1, 1 - memA / memT))
        if (root._prevNet) {
            const dt = (Date.now() - root._prevNet.t) / 1000
            if (dt > 0.5) {
                root.rxRate = Math.max(0, (rx - root._prevNet.rx) / dt)
                root.txRate = Math.max(0, (tx - root._prevNet.tx) / dt)
            }
        }
        root._prevNet = { rx: rx, tx: tx, t: Date.now() }
    }
    Process {
        id: statProc
        command: ["bash", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; " +
            "tail -n +3 /proc/net/dev; " +
            'for h in /sys/class/hwmon/hwmon*; do case "$(cat $h/name 2>/dev/null)" in coretemp|k10temp|zenpower) printf "temp:%s\\n" "$(cat $h/temp1_input 2>/dev/null)"; break;; esac; done; ' +
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; " +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1; true"]
        stdout: StdioCollector { onStreamFinished: root.parseStats(text) }
    }
    Timer {
        interval: 2500; repeat: true; running: !root.occluded; triggeredOnStart: true
        onTriggered: statProc.running = true
    }
}
