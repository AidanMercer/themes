import QtQuick
import QtQuick.Effects
import Quickshell

// bog: bare lock (the bareLock marker tells LockStage we own the chrome).
// Locking doesn't darken this desktop — the pond simply keeps you a while.
// The video stays sharp and slow; a leaf-dark raft panel SURFACES on the
// open water beneath the painted raft, blurring its own slice of pond, and
// carries the time in storybook serif with its shader reflection. The
// passcode is a fishing line strung with cork floats: every keystroke is a
// bite that pulls one float under (with a ripple), a wrong code snags the
// line — every float pops back up rust-red and the raft rocks — and the
// right one lets the line run free: rings bloom and the panel settles back
// beneath the surface as the pond lets you go.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color reed: pal.dim
    readonly property color straw: pal.text
    readonly property color murk: pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function strawA(a) { return Qt.rgba(straw.r, straw.g, straw.b, a) }
    function reedA(a)  { return Qt.rgba(reed.r, reed.g, reed.b, a) }
    function murkA(a)  { return Qt.rgba(murk.r, murk.g, murk.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")
    function spokenDate(d) {
        const ord = ["first","second","third","fourth","fifth","sixth","seventh",
            "eighth","ninth","tenth","eleventh","twelfth","thirteenth",
            "fourteenth","fifteenth","sixteenth","seventeenth","eighteenth",
            "nineteenth","twentieth","twenty-first","twenty-second",
            "twenty-third","twenty-fourth","twenty-fifth","twenty-sixth",
            "twenty-seventh","twenty-eighth","twenty-ninth","thirtieth",
            "thirty-first"]
        return Qt.formatDateTime(d, "dddd").toLowerCase() + ", the "
             + ord[d.getDate() - 1] + " of "
             + Qt.formatDateTime(d, "MMMM").toLowerCase()
    }

    // ── the pond dims only a little: noon holds ────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.04, 0.01, 0.22 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.35
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.01, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.03, 0.01, 0.5) }
        }
    }

    // ── the ripple verb ─────────────────────────────────────────────────────
    component Ripple: Canvas {
        id: rip
        property real t: -1
        property color tone: root.straw
        property real maxR: 60 * root.ui
        visible: t >= 0
        width: maxR * 2.3
        height: maxR
        onTChanged: requestPaint()
        function splash() { ripAnim.restart() }
        NumberAnimation {
            id: ripAnim
            target: rip; property: "t"
            from: 0; to: 1; duration: 1800; easing.type: Easing.OutSine
            onStopped: rip.t = -1
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (t < 0) return
            for (let k = 0; k < 3; k++) {
                const tt = (t - k * 0.17) / (1 - k * 0.17)
                if (tt <= 0 || tt >= 1) continue
                const r = maxR * (0.12 + 0.88 * tt)
                ctx.save()
                ctx.translate(width / 2, height / 2)
                ctx.scale(1, 0.3)
                ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                ctx.restore()
                ctx.strokeStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.4 * (1 - tt)))
                ctx.lineWidth = Math.max(0.8, 2.2 * (1 - tt))
                ctx.stroke()
            }
        }
    }

    // ── the raft panel, surfacing on the open water low-center ─────────────
    readonly property real panelW: Math.round(460 * ui)
    readonly property real panelH: Math.round(280 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        // surfaces: rises through its waterline as the lock engages
        y: Math.round(root.height * 0.60) + Math.round(46 * (1 - root.p))
        opacity: root.p

        // its slow water line while it floats
        property real bobY: 0
        property real rock: 0
        transform: [
            Translate { y: panel.bobY },
            Rotation { origin.x: panel.width / 2; origin.y: panel.height; angle: panel.rock }
        ]
        SequentialAnimation on bobY {
            running: root.p > 0.9
            loops: Animation.Infinite
            NumberAnimation { to: 3; duration: 4800; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 4800; easing.type: Easing.InOutSine }
        }

        // the panel blurs its own slice of the pond
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            maskEnabled: true
            maskSource: panelMask
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.18
            saturation: -0.1
        }
        Item {
            id: panelMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: Math.round(26 * root.ui); color: "black" }
        }
        Rectangle {
            anchors.fill: parent
            radius: Math.round(26 * root.ui)
            color: root.murkA(0.55)
            border.width: 1
            border.color: Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.4)
        }
        // the waterline across the panel, above the float string
        Rectangle {
            x: Math.round(28 * root.ui)
            y: Math.round(panel.height * 0.66)
            width: panel.width - Math.round(56 * root.ui)
            height: 1
            color: root.reedA(0.6)
        }
        Repeater {
            model: 5
            Rectangle {
                required property int index
                x: Math.round(40 * root.ui) + index * Math.round(84 * root.ui)
                y: Math.round(panel.height * 0.66) - 1
                width: (index % 2 === 0 ? 20 : 10) * root.ui
                height: 2
                radius: 1
                color: root.sunA(0.3)
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(26 * root.ui)
            spacing: Math.round(6 * root.ui)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "the pond lets you go"
                                          : "the pond keeps you a while"
                color: root.host.unlocking ? root.moss : root.sunA(0.85)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(15 * root.ui)
                font.letterSpacing: 2
            }

            Item { width: 1; height: Math.round(2 * root.ui) }

            Item {
                id: timeBlock
                anchors.horizontalCenter: parent.horizontalCenter
                width: bigTime.implicitWidth
                height: bigTime.implicitHeight
                Text {
                    id: bigTime
                    text: root.hhmm
                    color: root.strawA(0.95)
                    font.family: root.serif
                    font.weight: Font.Light
                    font.pixelSize: Math.round(64 * root.ui)
                    font.letterSpacing: 3
                }
            }
            // the time's ghost, wavering through the pond shader
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeBlock.width
                height: Math.round(20 * root.ui)
                ShaderEffectSource {
                    id: timeSrc
                    sourceItem: timeBlock
                    hideSource: false
                    live: true
                    visible: false
                }
                ShaderEffect {
                    anchors.fill: parent
                    fragmentShader: Qt.resolvedUrl("reflect.frag.qsb")
                    property var source: timeSrc
                    property real time: 0
                    property real amp: 0.02
                    opacity: 0.45
                    NumberAnimation on time {
                        from: 0; to: 600; duration: 600000
                        loops: Animation.Infinite
                        running: root.p > 0.5
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.spokenDate(clock.date)
                color: root.strawA(0.6)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(14 * root.ui)
                font.letterSpacing: 1
            }
        }

        // ── the float string: the passcode on a fishing line ────────────────
        Row {
            id: floatString
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(panel.height * 0.66) - Math.round(9 * root.ui)
            spacing: Math.round(13 * root.ui)
            Repeater {
                model: Math.max(8, Math.min(14, root.host.pwLength))
                delegate: Item {
                    id: sock
                    required property int index
                    readonly property bool bitten: index < root.host.pwLength
                    width: Math.round(9 * root.ui)
                    height: Math.round(22 * root.ui)
                    // the float: cork cap + straw belly, pulled under on a bite
                    Item {
                        id: cork
                        width: parent.width
                        height: Math.round(11 * root.ui)
                        y: sock.bitten ? Math.round(11 * root.ui) : 0
                        opacity: sock.bitten ? 0.45 : 0.95
                        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
                        Behavior on opacity { NumberAnimation { duration: 600 } }
                        Rectangle {
                            width: parent.width; height: parent.height * 0.5
                            radius: width / 2
                            color: root.host.failed ? root.rust
                                 : sock.bitten ? root.moss : root.rust
                        }
                        Rectangle {
                            y: parent.height * 0.42
                            width: parent.width; height: parent.height * 0.52
                            radius: width / 2
                            color: root.host.failed ? Qt.rgba(root.rust.r, root.rust.g, root.rust.b, 0.6)
                                 : sock.bitten ? Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.5)
                                 : root.sunA(0.85)
                        }
                    }
                    // its ripple when the bite lands
                    onBittenChanged: if (bitten && !root.host.failed) biteRip.splash()
                    Ripple {
                        id: biteRip
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(14 * root.ui)
                        maxR: 16 * root.ui
                        tone: root.straw
                    }
                }
            }
        }

        Text {
            id: prompt
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(panel.height * 0.66) + Math.round(22 * root.ui)
            text: root.host.failed ? "the line snagged — cast again"
                : root.host.busy ? "drawing up the line…"
                : root.host.pwLength > 0 ? "enter, and come ashore"
                : "cast your line"
            color: root.host.failed ? root.rust : root.strawA(0.6)
            font.family: root.serif
            font.italic: true
            font.pixelSize: Math.round(13 * root.ui)
            font.letterSpacing: 1
            // the idle prompt breathes — slow, never a blink
            SequentialAnimation on opacity {
                running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.failed && !root.host.unlocking
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
            }
        }

        // wrong code: the raft takes the snag and rocks it off
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) snagRock.restart() }
            function onUnlockingChanged() {
                if (root.host.unlocking) { farewell1.splash(); farewell2.splash() }
            }
        }
        SequentialAnimation {
            id: snagRock
            NumberAnimation { target: panel; property: "rock"; to: -1.6; duration: 260; easing.type: Easing.InOutSine }
            NumberAnimation { target: panel; property: "rock"; to: 1.1; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { target: panel; property: "rock"; to: -0.5; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { target: panel; property: "rock"; to: 0; duration: 380; easing.type: Easing.OutSine }
        }

        // farewell rings as the pond lets go
        Ripple {
            id: farewell1
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(panel.height * 0.62)
            maxR: 130 * root.ui
            tone: root.sun
        }
        Ripple {
            id: farewell2
            x: panel.width * 0.16
            y: Math.round(panel.height * 0.72)
            maxR: 60 * root.ui
            tone: root.moss
        }
    }

    // whose pond this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * root.ui)
        text: "≈ slow noon"
        color: root.strawA(0.35)
        font.family: root.serif
        font.italic: true
        font.pixelSize: Math.round(13 * root.ui)
        font.letterSpacing: 3
        opacity: root.p
    }
}
