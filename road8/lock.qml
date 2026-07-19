import QtQuick
import QtQuick.Effects
import Quickshell

// road8: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking doesn't dim this desktop — it PAUSES it. The video keeps rolling
// full-bleed and sharp: the car stays parked, the city keeps glowing, and a
// game pause dialog drops onto the middle of the screen in chunky steps — a
// pixel-cut panel blurring its own slice of the night, "PAUSED" across the
// top, the time in the house 5×7 pixel digits, and a coin slot row for the
// passcode: INSERT COIN blinks until you type, every keystroke drops a coin
// in, a wrong code flashes the coins taillight-red and knocks the tray
// sideways, and the moment the code lands the sign flips to PRESS START and
// a pair of taillights wipes across the screen as the night lets you back in.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── house pixel font ────────────────────────────────────────────────────
    readonly property var pixmap: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["000","000","010","000","010","000","000"],
        " ": ["00000","00000","00000","00000","00000","00000","00000"]
    })
    component PixelGlyph: Canvas {
        id: g
        property string ch: " "
        property real cell: 10
        property color face: root.amber
        readonly property var m: root.pixmap[ch] || root.pixmap[" "]
        width: (m[0].length + 0.4) * cell
        height: (m.length + 0.4) * cell
        onChChanged: requestPaint()
        onFaceChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = cell, gap = Math.max(1, c * 0.16)
            ctx.fillStyle = String(Qt.rgba(0, 0, 0, 0.5))
            for (let r = 0; r < m.length; r++)
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c + c * 0.32, r * c + c * 0.32, c - gap, c - gap)
            ctx.fillStyle = String(face)
            for (let r = 0; r < m.length; r++)
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c, r * c, c - gap, c - gap)
        }
    }

    // ── the night holds still: a light vignette, the video stays sharp ─────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.01, 0.02, 0.05, 0.26 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.30
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.02, 0.05, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.05, 0.45) }
        }
    }

    // ── the pause dialog ────────────────────────────────────────────────────
    readonly property real panelW: Math.round(430 * ui)
    readonly property real panelH: Math.round(300 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        // drops in on a 6px grid — the dialog arrives in steps, not a glide
        y: Math.round((root.height - height) * 0.44) - Math.round(36 * (1 - root.p) / 6) * 6
        opacity: root.p

        // the panel blurs its own slice of the road behind it
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: 5
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.22
            saturation: -0.15
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            color: root.glassA(0.55)
        }
        // pixel-cut frame on top
        Canvas {
            id: frame
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root.pal
                function onNeonChanged() { frame.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const w = width, h = height, s = 8
                ctx.beginPath()
                ctx.moveTo(s, 1)
                ctx.lineTo(w - s, 1)
                ctx.lineTo(w - s, s); ctx.lineTo(w - 1, s)
                ctx.lineTo(w - 1, h - s); ctx.lineTo(w - s, h - s)
                ctx.lineTo(w - s, h - 1); ctx.lineTo(s, h - 1)
                ctx.lineTo(s, h - s); ctx.lineTo(1, h - s)
                ctx.lineTo(1, s); ctx.lineTo(s, s)
                ctx.closePath()
                ctx.strokeStyle = String(root.amberA(0.75))
                ctx.lineWidth = 2
                ctx.stroke()
                // inner shadow line, one pixel in — the dialog's bevel
                ctx.strokeStyle = String(Qt.rgba(0, 0, 0, 0.4))
                ctx.lineWidth = 1
                ctx.strokeRect(s + 2.5, s + 2.5, w - 2 * s - 5, h - 2 * s - 5)
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(34 * root.ui)
            spacing: Math.round(18 * root.ui)

            // the sign: PAUSED, or PRESS START on the way out
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "▸ PRESS START ▸" : "— PAUSED —"
                color: root.host.unlocking ? root.starlight : root.amber
                font.family: root.mono
                font.weight: Font.Bold
                font.pixelSize: Math.round(16 * root.ui)
                font.letterSpacing: 8
            }

            // the time in fat pixels
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(8 * root.ui)
                Repeater {
                    model: 5
                    PixelGlyph {
                        required property int index
                        ch: root.hhmm.charAt(index)
                        cell: 10 * root.ui
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.6)
                font.family: root.mono
                font.pixelSize: Math.round(12 * root.ui)
                font.letterSpacing: 6
            }

            // center line dashes
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Repeater {
                    model: 7
                    Rectangle { width: 12 * root.ui; height: 3 * root.ui; color: root.amberA(0.5) }
                }
            }

            // ── the coin tray ───────────────────────────────────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(12 * root.ui)

                Row {
                    id: coinTray
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(9 * root.ui)
                    Repeater {
                        model: Math.max(8, Math.min(14, root.host.pwLength))
                        delegate: Item {
                            id: socket
                            required property int index
                            readonly property bool filled: index < root.host.pwLength
                            width: Math.round(11 * root.ui)
                            height: width
                            // the slot
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: root.slateA(0.9)
                            }
                            // the coin
                            Rectangle {
                                id: coin
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: width
                                radius: 1
                                color: root.host.failed ? root.tail : root.amber
                                visible: socket.filled
                                opacity: root.host.busy ? 0.5 : 1
                                onVisibleChanged: if (visible) drop.restart()
                                SequentialAnimation {
                                    id: drop
                                    NumberAnimation { target: coin; property: "scale"; from: 1.6; to: 1; duration: 110; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool tick: true
                    text: root.host.failed ? "WRONG CODE — TRY AGAIN"
                        : root.host.busy ? "CHECKING…"
                        : root.host.pwLength > 0 ? "ENTER TO START"
                        : "INSERT COIN"
                    color: root.host.failed ? root.tail : root.inkA(0.55)
                    // INSERT COIN blinks like an attract screen: hard on, hard off
                    opacity: (root.host.pwLength === 0 && !root.host.failed && prompt.tick) || root.host.pwLength > 0 || root.host.failed
                             ? 1 : 0.15
                    font.family: root.mono
                    font.pixelSize: Math.round(11 * root.ui)
                    font.letterSpacing: 4
                    Timer {
                        interval: 800; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        // start each attract cycle lit — the blink may have
                        // parked on the dark phase last time it stopped
                        onRunningChanged: if (running) prompt.tick = true
                        onTriggered: prompt.tick = !prompt.tick
                    }
                }
            }
        }

        // wrong password: the whole tray takes the hit
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) shake.restart() }
            function onUnlockingChanged() { if (root.host.unlocking) wipeAnim.restart() }
        }
        // the knock is stepped, like the tray slamming a pixel at a time
        SequentialAnimation {
            id: shake
            PropertyAction { target: panel; property: "sx"; value: -10 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 8 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: -4 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 0 }
        }
        property int sx: 0
        transform: Translate { x: panel.sx }
    }

    // whose game this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * root.ui)
        text: "8BIT2 · BEFORE THE ROAD"
        color: root.inkA(0.35)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p
    }

    // ── the unlock wipe: taillights across the whole night ─────────────────
    Item {
        id: wipe
        property real t: -1
        visible: t >= 0
        x: Math.round((-60 + root.width * 1.15 * Math.max(0, t)) / 12) * 12
        y: root.height * 0.46
        Rectangle { x: 0; width: 10 * root.ui; height: 8 * root.ui; color: root.tail }
        Rectangle { x: 16 * root.ui; width: 10 * root.ui; height: 8 * root.ui; color: root.tail }
        Rectangle { x: -14 * root.ui; width: 8 * root.ui; height: 8 * root.ui; color: root.amberA(0.3) }
        NumberAnimation {
            id: wipeAnim
            target: wipe; property: "t"
            from: 0; to: 1; duration: 650; easing.type: Easing.InQuad
            onStopped: wipe.t = -1
        }
    }
}
