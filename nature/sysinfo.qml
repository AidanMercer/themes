import QtQuick
import Quickshell
import Quickshell.Io

// nature — "golden hour" system readout: a botanist's field journal.
//
// A cream paper card pinned bottom-right (above the cava meadow), tilted a
// hair like it was set down in the grass. Hand-journal readings in dark pine
// ink with a soft serif — every gauge is a vine: a curved stem with small
// leaves that fill in as the value climbs.
//   sunlight  — CPU load (a little sun that brightens with load)
//   soil      — MEM used (a water-drop icon, soil moisture)
//   canopy    — GPU util (hidden without nvidia-smi)
//   dew       — battery (hidden on desktops)
//   breeze    — connection + up/down rates
// Reads /proc + nmcli itself; self-contained, click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color pine:  pal.glass
    readonly property color cream: pal.text
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono:  pal.fontMono
    readonly property string icon:  "Symbols Nerd Font"

    // paper + ink derived from the palette so config.toml retints live
    function toWhite(c, t) {
        return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, 1)
    }
    readonly property color paper: toWhite(cream, 0.4)
    readonly property color ink: Qt.rgba(pine.r * 0.75, pine.g * 0.75, pine.b * 0.75, 1)
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    readonly property color goldInk: Qt.darker(gold, 1.15)
    readonly property color leafInk: Qt.darker(leaf, 1.3)
    readonly property color roseInk: Qt.darker(rose, 1.2)

    // ── live state ──────────────────────────────────────────────────────────
    property int cpuPercent: -1
    property real prevTotal: 0
    property real prevIdle: 0
    property int cpuTemp: -1

    property int ramPercent: -1
    property real ramUsedGb: 0
    property real ramTotalGb: 0

    property bool hasGpu: false
    property int gpuPercent: -1

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

    function tone(v, warn, crit) {
        return v >= crit ? roseInk : v >= warn ? Qt.darker(pal.amber, 1.15) : leafInk
    }
    function pct(v) { return v < 0 ? "--" : v + "%" }
    function fmtRate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s"
                            : Math.round(b / 1024) + " KB/s"
    }

    // boot-in: the journal is laid down on the grass
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    // ── pollers ─────────────────────────────────────────────────────────────
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statProc.running = true; memProc.running = true; devProc.running = true }
    }
    Timer {
        interval: 6000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { batProc.running = true; upProc.running = true; gpuProc.running = true; tempProc.running = true }
    }
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: statProc
        command: ["cat", "/proc/stat"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseStat(text) }
    }
    function parseStat(raw) {
        const line = raw.split("\n")[0]
        if (!line || !line.startsWith("cpu")) return
        const f = line.trim().split(/\s+/).slice(1).map(Number)
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
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim().split("\n")[0])
                if (isNaN(v)) { root.hasGpu = false; return }
                root.hasGpu = true
                root.gpuPercent = Math.round(v)
            }
        }
    }

    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cap = parseInt(lines[0])
                if (lines[0] === "" || isNaN(cap)) { root.hasBattery = false; return }
                root.hasBattery = true
                root.batteryPercent = cap
                root.batteryCharging = (lines[1] || "").trim() === "Charging"
            }
        }
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

    Process {
        id: upProc
        command: ["cat", "/proc/uptime"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let s = Math.floor(parseFloat(text.trim().split(/\s+/)[0]) || 0)
                const dd = Math.floor(s / 86400); s -= dd * 86400
                const hh = Math.floor(s / 3600); s -= hh * 3600
                const mm = Math.floor(s / 60)
                root.uptimeText = dd > 0 ? `${dd}d ${hh}h` : hh > 0 ? `${hh}h ${mm}m` : `${mm}m`
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connName = ""; root.connType = ""; return }
                const i = line.lastIndexOf(":")
                root.connName = line.slice(0, i)
                const t = line.slice(i + 1)
                root.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                root.online = true
            }
        }
    }

    // ── the vine meter: a curved stem whose leaves fill in with the value ──
    component VineMeter: Canvas {
        id: vine
        property real value: 0          // 0..100
        property color fillTone: root.leafInk
        readonly property int leaves: 11
        width: parent ? parent.width : 100
        height: Math.round(15 * root.ui)
        onValueChanged: requestPaint()
        onFillToneChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            if (w <= 0) return
            const midY = h * 0.62
            // the stem, gently curved
            ctx.strokeStyle = root.inkA(0.55)
            ctx.lineWidth = 1.1 * root.ui
            ctx.beginPath()
            ctx.moveTo(0, midY + 1.5)
            ctx.quadraticCurveTo(w * 0.5, midY - 3.5 * root.ui, w, midY + 0.5)
            ctx.stroke()
            // leaves along the stem, alternating up/down
            const lit = Math.round(Math.max(0, Math.min(100, value)) / 100 * leaves)
            for (let i = 0; i < leaves; i++) {
                const t = (i + 0.5) / leaves
                const x = t * w
                const y = midY + 1.5 + (midY - 3.5 * root.ui - (midY + 0.5)) * (4 * t * (1 - t)) * 0.5
                const up = i % 2 === 0 ? -1 : 1
                ctx.save()
                ctx.translate(x, y)
                ctx.rotate(up * 0.9)
                ctx.beginPath()
                ctx.ellipse(-4.4 * root.ui, -2.1 * root.ui, 8.8 * root.ui, 4.2 * root.ui)
                if (i < lit) {
                    ctx.fillStyle = Qt.rgba(fillTone.r, fillTone.g, fillTone.b, 0.9)
                    ctx.fill()
                } else {
                    ctx.strokeStyle = root.inkA(0.3)
                    ctx.lineWidth = 0.9
                    ctx.stroke()
                }
                ctx.restore()
            }
        }
        Connections {
            target: root.pal
            function onCyanChanged()  { vine.requestPaint() }
            function onGlassChanged() { vine.requestPaint() }
        }
    }

    // a journal entry row: hand label left, reading right
    component EntryLine: Item {
        property string glyph: ""
        property color glyphTone: root.goldInk
        property string label: ""
        property string reading: ""
        property color readingTone: root.ink
        width: parent ? parent.width : 0
        implicitHeight: Math.round(18 * root.ui)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(7 * root.ui)
            Text {
                id: entryGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: glyph
                font.family: root.icon
                font.pixelSize: Math.round(12 * root.ui)
                color: glyphTone
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                width: Math.min(implicitWidth,
                    parent.parent.width - entryGlyph.width - entryReading.width
                    - Math.round(21 * root.ui))
                elide: Text.ElideRight
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(13 * root.ui)
                color: root.inkA(0.9)
            }
        }
        Text {
            id: entryReading
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: reading
            font.family: root.mono
            font.pixelSize: Math.round(12 * root.ui)
            font.weight: Font.DemiBold
            color: readingTone
        }
    }

    // ── the journal card ─────────────────────────────────────────────────────
    Item {
        id: card
        width: Math.round(272 * root.ui)
        height: col.implicitHeight + Math.round(34 * root.ui)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.round(30 * root.ui)
        anchors.bottomMargin: Math.round(232 * root.ui) - Math.round(14 * (1 - root.bootT))
        opacity: root.bootT
        rotation: -1.4 * root.bootT
        transformOrigin: Item.BottomRight

        // soft ground shadow
        Rectangle {
            anchors.fill: paperRect
            anchors.topMargin: 4 * root.ui
            anchors.leftMargin: -2 * root.ui
            radius: paperRect.radius
            color: Qt.rgba(0, 0, 0, 0.22)
        }

        Rectangle {
            id: paperRect
            anchors.fill: parent
            radius: Math.round(7 * root.ui)
            color: root.paper
            border.width: 1
            border.color: root.inkA(0.18)
        }

        // faint ruled lines, like a notebook page
        Canvas {
            id: rules
            anchors.fill: paperRect
            opacity: 0.5
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = root.inkA(0.09)
                ctx.lineWidth = 1
                for (let y = 44 * root.ui; y < height - 12; y += 22 * root.ui) {
                    ctx.beginPath()
                    ctx.moveTo(14 * root.ui, y)
                    ctx.lineTo(width - 14 * root.ui, y)
                    ctx.stroke()
                }
            }
            Connections {
                target: root.pal
                function onGlassChanged() { rules.requestPaint() }
            }
        }

        // pressed daisy in the top-right corner of the page
        Canvas {
            id: pressed
            width: Math.round(30 * root.ui)
            height: Math.round(30 * root.ui)
            anchors.right: paperRect.right
            anchors.top: paperRect.top
            anchors.margins: Math.round(9 * root.ui)
            opacity: 0.85
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const c = width / 2, pr = width * 0.3
                ctx.fillStyle = Qt.rgba(root.goldInk.r, root.goldInk.g, root.goldInk.b, 0.35)
                for (let i = 0; i < 5; i++) {
                    const a = -Math.PI / 2 + 0.35 + i * Math.PI * 2 / 5
                    ctx.save()
                    ctx.translate(c + Math.cos(a) * pr * 0.8, c + Math.sin(a) * pr * 0.8)
                    ctx.rotate(a + Math.PI / 2)
                    ctx.beginPath()
                    ctx.ellipse(-pr * 0.34, -pr * 0.8, pr * 0.68, pr * 1.6)
                    ctx.fill()
                    ctx.restore()
                }
                ctx.beginPath()
                ctx.arc(c, c, pr * 0.36, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(root.roseInk.r, root.roseInk.g, root.roseInk.b, 0.5)
                ctx.fill()
            }
            Connections {
                target: root.pal
                function onNeonChanged()    { pressed.requestPaint() }
                function onMagentaChanged() { pressed.requestPaint() }
            }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Math.round(17 * root.ui)
            anchors.rightMargin: Math.round(17 * root.ui)
            anchors.topMargin: Math.round(15 * root.ui)
            spacing: Math.round(6 * root.ui)

            // header
            Text {
                text: "field notes"
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(17 * root.ui)
                color: root.ink
            }
            Text {
                text: Qt.formatDateTime(new Date(), "MMMM d") + "  ·  the meadow"
                font.family: root.serif
                font.pixelSize: Math.round(10 * root.ui)
                font.letterSpacing: 1.5
                color: root.inkA(0.55)
            }
            Item { width: 1; height: Math.round(4 * root.ui) }

            // sunlight — CPU
            EntryLine {
                glyph: String.fromCodePoint(0xF0599)   // nf-md-weather_sunny
                glyphTone: root.goldInk
                label: "sunlight"
                reading: root.pct(root.cpuPercent)
                    + (root.cpuTemp > 0 ? "  " + root.cpuTemp + "°" : "")
                readingTone: root.tone(root.cpuPercent, 60, 85)
            }
            VineMeter { value: root.cpuPercent < 0 ? 0 : root.cpuPercent; fillTone: root.tone(root.cpuPercent, 60, 85) }

            // soil — MEM
            EntryLine {
                glyph: String.fromCodePoint(0xF058C)   // nf-md-water
                glyphTone: root.leafInk
                label: "soil"
                reading: root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " G"
                readingTone: root.tone(root.ramPercent, 70, 90)
            }
            VineMeter { value: root.ramPercent < 0 ? 0 : root.ramPercent; fillTone: root.tone(root.ramPercent, 70, 90) }

            // canopy — GPU (nvidia only)
            EntryLine {
                visible: root.hasGpu
                height: root.hasGpu ? implicitHeight : 0
                glyph: String.fromCodePoint(0xF0531)   // nf-md-tree
                glyphTone: root.leafInk
                label: "canopy"
                reading: root.pct(root.gpuPercent)
                readingTone: root.tone(root.gpuPercent, 60, 85)
            }
            VineMeter {
                visible: root.hasGpu
                height: root.hasGpu ? Math.round(15 * root.ui) : 0
                value: root.gpuPercent < 0 ? 0 : root.gpuPercent
                fillTone: root.tone(root.gpuPercent, 60, 85)
            }

            // dew — battery (laptops only)
            EntryLine {
                visible: root.hasBattery
                height: root.hasBattery ? implicitHeight : 0
                glyph: String.fromCodePoint(root.batteryCharging ? 0xF0084 : 0xF058E)  // charging / water-outline
                glyphTone: root.batteryCharging ? root.goldInk
                    : root.batteryPercent <= 20 ? root.roseInk : root.leafInk
                label: root.batteryCharging ? "dew, gathering" : "dew"
                reading: root.pct(root.batteryPercent)
                readingTone: root.batteryCharging ? root.goldInk
                    : root.batteryPercent <= 20 ? root.roseInk : root.ink
            }
            VineMeter {
                visible: root.hasBattery
                height: root.hasBattery ? Math.round(15 * root.ui) : 0
                value: root.batteryPercent < 0 ? 0 : root.batteryPercent
                fillTone: root.batteryCharging ? root.goldInk
                    : root.batteryPercent <= 20 ? root.roseInk : root.leafInk
            }

            Item { width: 1; height: Math.round(2 * root.ui) }

            // breeze — NET
            EntryLine {
                glyph: String.fromCodePoint(root.online
                    ? (root.connType === "eth" ? 0xF059F : 0xF05A9) : 0xF092F)
                glyphTone: root.online ? root.leafInk : root.roseInk
                label: root.online ? "breeze  ·  " + root.connName : "still air"
                reading: root.online
                    ? "↓" + root.fmtRate(root.rxRate) + " ↑" + root.fmtRate(root.txRate)
                    : "offline"
                readingTone: root.online ? root.inkA(0.75) : root.roseInk
            }

            // footer: uptime as a growing season
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: "— in bloom " + root.uptimeText
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(10 * root.ui)
                color: root.inkA(0.5)
            }
        }
    }
}
