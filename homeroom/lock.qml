import QtQuick
import QtQuick.Effects
import Quickshell
import "chalk.js" as Chalk

// homeroom: bare lock (the bareLock marker tells LockStage we own the whole
// screen). Locking doesn't darken the room — the room just holds its breath:
// the video keeps playing sharp, the light stays morning. A slate notice
// pins itself to the middle of the screen (tape tabs, crooked settle, its
// own blurred slice of the room behind it), the time is WRITTEN onto it in
// the house chalk hand, and above the board the halo — the room's one
// supernatural thing, saved for exactly this — draws itself in and breathes.
// Sign-in: every keystroke chalks a tally stroke, every fifth
// gates the four before it. A wrong code flashes the tallies stripe-pink,
// knocks the board on its pins, and the eraser smudges the marks away. The
// right code: the halo flares wide, "good morning", and the room lets you in.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color chalk: pal.text
    readonly property color halo: pal.neon
    readonly property color pink: pal.magenta
    readonly property color slate: pal.dim
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function haloA(a)  { return Qt.rgba(halo.r, halo.g, halo.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the room holds its breath: the lightest of veils, video stays sharp ─
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(glass.r, glass.g, glass.b, 0.18 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.28
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.34) }
        }
    }

    // ── the notice board ────────────────────────────────────────────────────
    readonly property real panelW: Math.round(430 * ui)
    readonly property real panelH: Math.round(295 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) * 0.42) - Math.round(26 * (1 - root.p))
        opacity: root.p
        rotation: -0.8 * root.p          // pinned things are never straight
        transformOrigin: Item.Top

        // the board blurs its own slice of the morning behind it
        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: 4
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.10
            saturation: -0.05
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 4
            color: root.glassA(0.62)
            border.width: 1
            border.color: root.slateA(0.55)
        }
        // tape tabs
        Rectangle { x: 40 * root.ui; y: -2; width: 30 * root.ui; height: 11; rotation: -34; color: root.chalkA(0.42) }
        Rectangle { x: panel.width - 72 * root.ui; y: -2; width: 30 * root.ui; height: 11; rotation: 31; color: root.chalkA(0.42) }

        // hand-chalked frame inside the edge
        Canvas {
            id: frame
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const w = width, h = height, m = 14
                Chalk.strokePath(ctx, [[m, m], [w - m, m + 2], [w - m - 2, h - m], [m + 2, h - m - 2], [m, m]], {
                    seed: 131, color: String(root.chalkA(1)), alpha: 0.32,
                    width: 2.4, dust: 0.08
                })
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root.pal
                function onTextChanged() { frame.requestPaint() }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(36 * root.ui)
            spacing: Math.round(14 * root.ui)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "good morning" : "homeroom"
                color: root.host.unlocking ? root.halo : root.chalkA(0.66)
                font.family: root.mono
                font.pixelSize: Math.round(13 * root.ui)
                font.letterSpacing: 6
            }

            // the time, written in the house chalk hand
            Canvas {
                id: timeChalk
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(240 * root.ui)
                height: Math.round(74 * root.ui)
                property real reveal: 0
                onRevealChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cellH = height
                    const widths = [0.78, 0.78, 0.42, 0.78, 0.78]
                    let total = 0
                    for (const f of widths) total += f * cellH * 0.92
                    total += 4 * 10 * root.ui
                    let x = (width - total) / 2
                    for (let i = 0; i < 5; i++) {
                        const gw = widths[i] * cellH * 0.92
                        // stagger: digits are written one after another
                        const r = Math.max(0, Math.min(1, root.hhmm ? (timeChalk.reveal * 5.6 - i) : 0))
                        Chalk.drawGlyph(ctx, root.hhmm.charAt(i), x, 0, gw, cellH, {
                            seed: 211 + i * 19, color: String(root.chalkA(0.94)), alpha: 0.94,
                            width: Math.max(3, cellH * 0.075), reveal: r
                        })
                        x += gw + 10 * root.ui
                    }
                }
                // written once the board has landed; re-written on re-lock
                readonly property bool landed: root.p > 0.5
                onLandedChanged: {
                    if (landed) writeIn.restart()
                    else { writeIn.stop(); reveal = 0 }
                }
                NumberAnimation { id: writeIn; target: timeChalk; property: "reveal"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutSine }
                Connections {
                    target: clock
                    function onDateChanged() { timeChalk.requestPaint() }
                }
                Connections {
                    target: root.pal
                    function onTextChanged() { timeChalk.requestPaint() }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                color: root.chalkA(0.55)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 4
            }

            Item { width: 1; height: Math.round(2 * root.ui) }

            // ── sign-in: the tally strip ────────────────────────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(10 * root.ui)

                Canvas {
                    id: tallies
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(230 * root.ui)
                    height: Math.round(30 * root.ui)
                    property int n: Math.min(15, root.host.pwLength)
                    property bool bad: root.host.failed
                    property real wipe: 0          // eraser pass on failure
                    onNChanged: requestPaint()
                    onBadChanged: requestPaint()
                    onWipeChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const u = root.ui
                        const col = bad ? String(Qt.rgba(root.pink.r, root.pink.g, root.pink.b, 1))
                                        : String(root.chalkA(1))
                        ctx.globalAlpha = wipe > 0 ? Math.max(0, 1 - wipe * 1.2) : 1
                        for (let i = 0; i < n; i++) {
                            const grp = Math.floor(i / 5)
                            const pos = i % 5
                            const gx = 8 + grp * 74 * u
                            if (pos < 4) {
                                Chalk.strokePath(ctx, [[gx + pos * 13 * u, 4], [gx + pos * 13 * u + 2, height - 5]], {
                                    seed: 401 + i * 11, color: col, alpha: 0.92, width: 2.6 * u, dust: 0.10
                                })
                            } else {
                                Chalk.strokePath(ctx, [[gx - 5 * u, height - 8], [gx + 44 * u, 6]], {
                                    seed: 431 + i * 13, color: col, alpha: 0.92, width: 2.8 * u, dust: 0.12
                                })
                            }
                        }
                        ctx.globalAlpha = 1
                        if (wipe > 0)
                            Chalk.drawSmudge(ctx, 0, 0, width, height, wipe, String(root.chalkA(1)), 17)
                        // the sign-in line
                        Chalk.strokePath(ctx, [[4, height - 2], [width - 4, height - 3]], {
                            seed: 7, color: String(root.chalkA(1)), alpha: 0.25, width: 1.6, ghost: false, dust: 0
                        })
                    }
                    NumberAnimation {
                        id: eraseTallies
                        target: tallies; property: "wipe"
                        from: 0; to: 1; duration: 500; easing.type: Easing.InOutQuad
                        onStopped: tallies.wipe = 0
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool breath: true
                    text: root.host.failed ? "wrong password — try again"
                        : root.host.busy ? "checking…"
                        : root.host.pwLength > 0 ? "⏎ to unlock"
                        : "type your password"
                    color: root.host.failed ? root.pink : root.chalkA(0.6)
                    opacity: (root.host.pwLength === 0 && !root.host.failed) ? (breath ? 0.9 : 0.35) : 1
                    Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutSine } }
                    font.family: root.mono
                    font.pixelSize: Math.round(11 * root.ui)
                    font.letterSpacing: 3
                    Timer {
                        interval: 1400; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        onTriggered: prompt.breath = !prompt.breath
                    }
                }
            }
        }

        // wrong code: the board takes a knock on its pins
        Connections {
            target: root.host
            function onFailedChanged() {
                if (root.host.failed) { knock.restart(); eraseTallies.restart() }
            }
            function onUnlockingChanged() { if (root.host.unlocking) flare.restart() }
        }
        SequentialAnimation {
            id: knock
            NumberAnimation { target: panel; property: "rotation"; to: -2.6; duration: 70 }
            NumberAnimation { target: panel; property: "rotation"; to: 0.9; duration: 120 }
            NumberAnimation { target: panel; property: "rotation"; to: -1.3; duration: 140 }
            NumberAnimation { target: panel; property: "rotation"; to: -0.8; duration: 160 }
        }
    }

    // ── the halo, above the board — drawn in as the lock lands ─────────────
    Canvas {
        id: bigHalo
        anchors.horizontalCenter: panel.horizontalCenter
        y: panel.y - Math.round(58 * root.ui)
        width: Math.round(150 * root.ui)
        height: Math.round(54 * root.ui)
        property real sweep: 0
        property real breathe: 1
        property real flareT: 0
        opacity: root.p * (1 - flareT)
        scale: 1 + flareT * 0.9
        visible: opacity > 0.01
        onSweepChanged: requestPaint()
        onBreatheChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (sweep <= 0.01) return
            const cx = width / 2, cy = height / 2
            const rx = width * 0.40, ry = height * 0.30
            const a0 = -Math.PI * 0.5
            const a1 = a0 + Math.PI * 2 * sweep
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(1, ry / rx)
            ctx.beginPath(); ctx.arc(0, 0, rx, a0, a1)
            ctx.strokeStyle = String(root.haloA(0.20 * breathe))
            ctx.lineWidth = 16; ctx.lineCap = "round"; ctx.stroke()
            ctx.beginPath(); ctx.arc(0, 0, rx, a0, a1)
            ctx.strokeStyle = String(root.haloA(0.55 * breathe))
            ctx.lineWidth = 7; ctx.stroke()
            ctx.beginPath(); ctx.arc(0, 0, rx, a0, a1)
            ctx.strokeStyle = String(root.haloA(0.98 * breathe))
            ctx.lineWidth = 2.6; ctx.stroke()
            ctx.restore()
        }
        // draw in once the board has landed (sweep/flareT are reset after the
        // unlock flare — the instance survives lock cycles, so a stale sweep=1
        // or flareT=1 would leave the next lock without its halo)
        readonly property bool landed: root.p > 0.85
        onLandedChanged: if (landed && sweep < 1) ringIn.restart()
        NumberAnimation { id: ringIn; target: bigHalo; property: "sweep"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutQuad }
        // and breathe, slowly, while the room waits
        SequentialAnimation on breathe {
            running: root.p > 0.9 && !root.host.unlocking
            loops: Animation.Infinite
            NumberAnimation { to: 0.72; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
        }
        // unlock: the flare — then rearm for the next lock
        NumberAnimation {
            id: flare; target: bigHalo; property: "flareT"
            from: 0; to: 1; duration: 650; easing.type: Easing.OutQuad
            onStopped: { bigHalo.sweep = 0; bigHalo.flareT = 0 }
        }
    }
}
