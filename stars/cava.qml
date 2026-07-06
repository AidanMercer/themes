import QtQuick
import Quickshell.Io

// stars: the machine comes alive. A vending shelf grid parked low over the
// dark platform, just under the shelter: 16 columns of little bottle-lights
// (one per cava bin) by 7 rows. Music lights each column bottom-up in warm
// amber — the topmost lit bottle at a real peak flashes coral-pink, like a
// bottle catching the cloud light. Silence is the machine at rest: the grid
// settles into a faint idle hum (a static dim glow, zero animation). Runs
// its own cava against cava.conf next door; click-through scenery.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color coral: pal.cyan
    readonly property color slate: pal.dim
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property int cols: 16
    readonly property int rows: 7

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values the grid binds to
    property bool humming: false  // false = true silence, the idle machine

    // boot-in: the shelves flicker on row by row
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1000; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const z = []
        for (let i = 0; i < cols; i++) z.push(0)
        display = z
    }

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
        onRunningChanged: if (!running) cavaRestart.start()
    }
    Timer {
        id: cavaRestart
        interval: 2000
        onTriggered: cava.running = true
    }

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length) root.levels = out
    }

    // smoothing pump — only rebinds the grid while something is moving;
    // at true silence `humming` drops and the timer's work is a cheap no-op
    // that stops dirtying the scene.
    property int stillFrames: 0
    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display
            const l = root.levels
            let moved = 0
            let peak = 0
            for (let i = 0; i < root.cols; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                const nv = d[i] + (t - d[i]) * 0.45
                moved += Math.abs(nv - d[i])
                d[i] = nv
                if (nv > peak) peak = nv
            }
            if (moved > 0.003) {
                root.display = d
                root.stillFrames = 0
                root.humming = true
            } else if (root.humming) {
                root.stillFrames++
                if (root.stillFrames > 45) {   // ~1.5s of stillness → machine at rest
                    for (let i = 0; i < root.cols; i++) d[i] = 0
                    root.display = d
                    root.humming = false
                }
            }
        }
    }

    // ── the machine face ────────────────────────────────────────────────────
    Item {
        id: machine
        readonly property real cellW: 20
        readonly property real cellH: 26
        readonly property real gapX: 7
        readonly property real gapY: 6
        width: root.cols * cellW + (root.cols - 1) * gapX + 36
        height: root.rows * cellH + (root.rows - 1) * gapY + 34
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.075)
        scale: pal.uiScale
        transformOrigin: Item.Bottom
        // the machine face only exists while music plays — at true silence it
        // fades out completely instead of squatting on the wallpaper
        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        // shelf chassis: a whisper of glass and a warm baseline, so the grid
        // reads as the machine's face without boxing the wallpaper in
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.glassA(root.humming ? 0.42 : 0.28)
            border.width: 1
            border.color: root.amberA(root.humming ? 0.28 : 0.14)
            Behavior on color { ColorAnimation { duration: 600 } }
            Behavior on border.color { ColorAnimation { duration: 600 } }
        }
        // light spilling onto the platform under the machine while it plays
        Rectangle {
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 1.1
            height: 46
            opacity: root.humming ? 0.65 : 0.18
            Behavior on opacity { NumberAnimation { duration: 600 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.amberA(0.14) }
                GradientStop { position: 1.0; color: root.amberA(0.0) }
            }
        }

        // the product grid
        Repeater {
            model: root.cols
            delegate: Item {
                id: colItem
                required property int index
                readonly property real lvl: root.display[index] || 0
                readonly property int litRows: Math.round(colItem.lvl * root.rows)
                x: 18 + index * (machine.cellW + machine.gapX)
                y: 17
                width: machine.cellW
                height: root.rows * machine.cellH + (root.rows - 1) * machine.gapY

                Repeater {
                    model: root.rows
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        // row 0 is the TOP shelf; light from the bottom up
                        readonly property int fromBottom: root.rows - 1 - index
                        readonly property bool lit: root.humming && fromBottom < colItem.litRows
                        readonly property bool tip: lit && fromBottom === colItem.litRows - 1 && colItem.lvl > 0.55
                        // boot flicker: rows come alive bottom-first
                        readonly property real bootRow: Math.max(0, Math.min(1, root.bootT * 2.2 - fromBottom * 0.18))

                        y: index * (machine.cellH + machine.gapY)
                        width: machine.cellW
                        height: machine.cellH
                        radius: 6
                        opacity: bootRow
                        color: lit ? (tip ? root.coral : root.amber) : "transparent"
                        border.width: 1
                        border.color: lit ? (tip ? root.coral : root.amberA(0.9))
                                          : root.slateA(root.humming ? 0.5 : 0.75)
                        Behavior on color { ColorAnimation { duration: 90 } }
                        Behavior on border.color { ColorAnimation { duration: 90 } }

                        // idle hum: unlit bottles keep the faintest warm fill,
                        // like product lit from deep inside the machine
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 4
                            color: root.amberA(cell.lit ? 0.0 : 0.07)
                        }
                        // bottle cap notch
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 2
                            width: 6; height: 2; radius: 1
                            color: cell.lit ? root.glassA(0.85) : root.slateA(0.5)
                        }
                        // glass shine on lit bottles
                        Rectangle {
                            x: 3; y: 6
                            width: 3; height: parent.height - 11
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, cell.lit ? 0.30 : 0.0)
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                    }
                }
            }
        }
    }
}
