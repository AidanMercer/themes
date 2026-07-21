import QtQuick
import QtQuick.Effects
import Quickshell

// thicket: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking doesn't dim this desktop — the THICKET CLOSES over it. The video
// stays sharp and full-bleed while dense borders of leaf silhouettes crowd in
// from every screen edge with the lock's progress, until you're looking at
// the desktop through a shrinking gap in the brush. In the middle, a hollow:
// a leaf-rimmed panel blurring its own slice of the scene, the time in
// serif, and a row of berries for the passcode — every keystroke ripens one
// ember. Above the panel a pair of pale eyes watches you type, blinking now
// and then. A wrong code startles them ember-red and the panel darts
// sideways in two hard steps. The right code closes the eyes gently and
// the leaves part back out.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color emberRed: pal.magenta
    readonly property color dapple: pal.amber
    readonly property color leaf: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)   { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function leafA(a)   { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // a faint hush over the scene — the light drops as the leaves close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.04, 0.03, 0.30 * root.p)
    }

    // ── the closing borders: leaves crowd in from every edge ───────────────
    component EdgeBrush: Canvas {
        id: eb
        property int edge: 0        // 0 top, 1 bottom, 2 left, 3 right
        property int seedBase: 0
        readonly property real depth: 130 * root.ui
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        function leafShape(ctx, x, y, len, wid, ang, fill) {
            ctx.save()
            ctx.translate(x, y); ctx.rotate(ang)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
            ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fill
            ctx.fill()
            ctx.restore()
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const along = (edge < 2) ? width : height
            const n = Math.ceil(along / 26)
            for (let i = 0; i < n * 2; i++) {
                const s = seedBase + i * 13
                const a = (i / (n * 2)) * along + (root.rnd(s + 1) - 0.5) * 30
                const d = root.rnd(s + 2) * depth * (i % 2 === 0 ? 0.55 : 1.0)
                const len = (34 + root.rnd(s + 3) * 46) * root.ui
                const wid = (9 + root.rnd(s + 4) * 10) * root.ui
                // pointing inward, scattered
                let x, y, ang
                if (edge === 0)      { x = a; y = d; ang = Math.PI / 2 + (root.rnd(s + 5) - 0.5) * 1.6 }
                else if (edge === 1) { x = a; y = height - d; ang = -Math.PI / 2 + (root.rnd(s + 5) - 0.5) * 1.6 }
                else if (edge === 2) { x = d; y = a; ang = (root.rnd(s + 5) - 0.5) * 1.6 }
                else                 { x = width - d; y = a; ang = Math.PI + (root.rnd(s + 5) - 0.5) * 1.6 }
                const r = root.rnd(s + 6)
                const fill = r < 0.22 ? "rgba(23,44,38,0.96)"
                           : r < 0.4 ? "rgba(16,22,19,0.97)"
                           : "rgba(6,10,8,0.97)"
                leafShape(ctx, x, y, len, wid, ang - Math.PI, fill)
            }
        }
    }
    // each border slides in with progress — position math, no repaints
    EdgeBrush {
        edge: 0; seedBase: 100
        width: parent.width; height: depth
        y: -depth * (1 - root.p) * 1.05 - 4
    }
    EdgeBrush {
        edge: 1; seedBase: 900
        width: parent.width; height: depth
        y: parent.height - height + depth * (1 - root.p) * 1.05 + 4
    }
    EdgeBrush {
        edge: 2; seedBase: 1700
        width: depth; height: parent.height
        x: -depth * (1 - root.p) * 1.05 - 4
    }
    EdgeBrush {
        edge: 3; seedBase: 2500
        width: depth; height: parent.height
        x: parent.width - width + depth * (1 - root.p) * 1.05 + 4
    }

    // ── the hollow ──────────────────────────────────────────────────────────
    readonly property real panelW: Math.round(430 * ui)
    readonly property real panelH: Math.round(290 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        // arrives in one quick dart as the leaves close
        y: Math.round((root.height - height) * 0.46) - Math.round(26 * (1 - root.p))
        opacity: root.p

        // the panel blurs its own slice of the thicket behind it
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: 6
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.24
            saturation: -0.2
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            radius: 14
            color: root.glassA(0.52)
            border.width: 1
            border.color: root.leafA(0.5)
        }
        // the rim of leaves the hollow was parted through
        Canvas {
            id: rim
            anchors.fill: parent
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height
                function leafShape(x, y, len, wid, ang, fill) {
                    ctx.save()
                    ctx.translate(x, y); ctx.rotate(ang)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                    ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                    ctx.closePath()
                    ctx.fillStyle = fill
                    ctx.fill()
                    ctx.restore()
                }
                for (let i = 0; i < 14; i++) {
                    const top = i < 8
                    const f = top ? i / 7 : (i - 8) / 5
                    const x = top ? w * (0.04 + f * 0.9) : w * (0.16 + f * 0.72)
                    const y = top ? 8 + (root.rnd(i * 7) - 0.5) * 8
                                  : h - 7 + (root.rnd(i * 7) - 0.5) * 7
                    const ang = (top ? 0.45 : -0.5) + (root.rnd(i * 31 + 2) - 0.5) * 1.2 + (top ? Math.PI : 0)
                    const teal = root.rnd(i * 41 + 6) < 0.3
                    leafShape(x, y, (20 + root.rnd(i * 17 + 9) * 22) * root.ui,
                              (5 + root.rnd(i * 23) * 4) * root.ui, ang,
                              teal ? "rgba(23,44,38,0.94)" : "rgba(6,10,8,0.94)")
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(38 * root.ui)
            spacing: Math.round(14 * root.ui)

            // the time, serif, lit like skin in the gap
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hhmm
                color: root.ink
                font.family: root.serif
                font.pixelSize: Math.round(74 * root.ui)
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.65)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                color: root.inkA(0.6)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(14 * root.ui)
            }

            // ── the berry row ───────────────────────────────────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(11 * root.ui)

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(9 * root.ui)
                    Repeater {
                        model: Math.max(8, Math.min(14, root.host.pwLength))
                        delegate: Item {
                            id: socket
                            required property int index
                            readonly property bool filled: index < root.host.pwLength
                            width: Math.round(12 * root.ui)
                            height: width
                            // the unripe husk
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: root.leafA(0.9)
                            }
                            // the berry, ripening ember
                            Rectangle {
                                id: berry
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: width
                                radius: width / 2
                                color: root.host.failed ? root.emberRed : root.ember
                                visible: socket.filled
                                opacity: root.host.busy ? 0.5 : 1
                                onVisibleChanged: if (visible) pop.restart()
                                NumberAnimation {
                                    id: pop
                                    target: berry; property: "scale"
                                    from: 1.7; to: 1; duration: 130
                                    easing.type: Easing.OutQuint
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool tick: true
                    text: root.host.failed ? "wrong — try again"
                        : root.host.busy ? "checking…"
                        : root.host.pwLength > 0 ? "press enter"
                        : "type to unlock"
                    color: root.host.failed ? root.emberRed : root.inkA(0.7)
                    opacity: (root.host.pwLength === 0 && !root.host.failed && !prompt.tick) ? 0.25 : 1
                    font.family: root.mono
                    font.pixelSize: Math.round(11 * root.ui)
                    font.letterSpacing: 4
                    Timer {
                        interval: 1400; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        onTriggered: prompt.tick = !prompt.tick
                    }
                }
            }
        }

        // wrong code: the panel darts sideways in hard steps — startled
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) shake.restart() }
        }
        SequentialAnimation {
            id: shake
            PropertyAction { target: panel; property: "sx"; value: -12 }
            PauseAnimation { duration: 60 }
            PropertyAction { target: panel; property: "sx"; value: 9 }
            PauseAnimation { duration: 60 }
            PropertyAction { target: panel; property: "sx"; value: -3 }
            PauseAnimation { duration: 60 }
            PropertyAction { target: panel; property: "sx"; value: 0 }
        }
        property int sx: 0
        transform: Translate { x: panel.sx }
    }

    // ── the eyes above the hollow, watching you type ───────────────────────
    Item {
        id: eyes
        width: Math.round(46 * root.ui)
        height: Math.round(15 * root.ui)
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.y - height - Math.round(26 * root.ui)
        opacity: root.p
        transformOrigin: Item.Center
        readonly property color shade: root.host.failed ? root.emberRed : root.iris

        Rectangle {
            x: 0; y: Math.round(4 * root.ui)
            width: Math.round(16 * root.ui); height: Math.round(10 * root.ui)
            radius: height / 2
            color: eyes.shade
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                x: Math.round(4 * root.ui); y: Math.round(2.5 * root.ui)
                width: Math.round(4 * root.ui); height: width; radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
        Rectangle {
            x: Math.round(30 * root.ui); y: 0
            width: Math.round(16 * root.ui); height: Math.round(10 * root.ui)
            radius: height / 2
            color: eyes.shade
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                x: Math.round(4 * root.ui); y: Math.round(2.5 * root.ui)
                width: Math.round(4 * root.ui); height: width; radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }

        SequentialAnimation {
            id: eyeBlink
            NumberAnimation { target: eyes; property: "scaleY"; to: 0.08; duration: 70; easing.type: Easing.InQuad }
            NumberAnimation { target: eyes; property: "scaleY"; to: 1; duration: 130; easing.type: Easing.OutQuint }
        }
        Timer {
            interval: 6000 + Math.random() * 7000
            repeat: true
            running: root.p > 0.9 && !root.host.unlocking
            onTriggered: { interval = 6000 + Math.random() * 7000; eyeBlink.restart() }
        }
        // unlocking: the eyes close and stay closed
        Connections {
            target: root.host
            function onUnlockingChanged() {
                if (root.host.unlocking) { eyeBlink.stop(); eyesClose.restart() }
            }
        }
        NumberAnimation {
            id: eyesClose
            target: eyes; property: "scaleY"
            to: 0.05; duration: 200; easing.type: Easing.InQuad
        }
    }

    // the signature
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(34 * root.ui)
        text: "THICKET"
        color: root.inkA(0.5)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p
    }
}
