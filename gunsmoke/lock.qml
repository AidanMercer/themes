import QtQuick
import QtQuick.Effects
import Quickshell

// gunsmoke: bare lock (the bareLock marker tells LockStage we own the whole
// chrome). Locking doesn't dim the hunt — it POSTS it. The video keeps
// rolling sharp behind a wanted poster that blooms out of the fog mid-screen:
// a slip of iron-dark paper blurring its own slice of the scene, double
// ledger rules, corner rivets, "№ 1887" in the corner. THE HUNT IS HELD
// across the top, the time stamped in serif blacks, and the passcode is the
// CYLINDER — a strip of chambers that load a round per keystroke (each seats
// with a hammer slam). A wrong code is a MISFIRE: every round flashes
// oxblood and the poster takes a stepped recoil knock. The right code drops
// the hammer — one frame of muzzle flash across the whole night, powder
// smoke curling up as the hunt lets you back in.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color bone: pal.neon
    readonly property color steel: pal.cyan
    readonly property color blood: pal.magenta
    readonly property color ash: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function ashA(a)   { return Qt.rgba(ash.r, ash.g, ash.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the night thickens a little: fog vignette, video stays sharp ───────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.04, 0.30 * root.p)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.04, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.03, 0.04, 0.5) }
        }
    }

    // ── the poster ─────────────────────────────────────────────────────────
    readonly property real panelW: Math.round(440 * ui)
    readonly property real panelH: Math.round(330 * ui)

    Item {
        id: panel
        width: root.panelW
        height: root.panelH
        x: Math.round((root.width - width) / 2)
        // smoke law: the poster blooms up out of the fog as the lock engages
        y: Math.round((root.height - height) * 0.42) + Math.round(26 * (1 - root.p))
        opacity: root.p

        // the poster blurs its own slice of the hunt behind it
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
            brightness: -0.24
            saturation: -0.5
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            color: root.glassA(0.55)
        }

        // ledger frame: double rules + corner rivets + the file number
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
                const w = width, h = height
                ctx.strokeStyle = String(root.boneA(0.65))
                ctx.lineWidth = 2
                ctx.strokeRect(4, 4, w - 8, h - 8)
                ctx.strokeStyle = String(root.boneA(0.22))
                ctx.lineWidth = 1
                ctx.strokeRect(10.5, 10.5, w - 21, h - 21)
                // corner rivets
                ctx.fillStyle = String(root.boneA(0.7))
                for (const [rx, ry] of [[8, 8], [w - 8, 8], [8, h - 8], [w - 8, h - 8]]) {
                    ctx.beginPath()
                    ctx.arc(rx, ry, 2.4, 0, 6.2832)
                    ctx.fill()
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Math.round(20 * root.ui)
            anchors.topMargin: Math.round(16 * root.ui)
            text: "№ 1887"
            color: root.ashA(1)
            font.family: root.serif
            font.pixelSize: Math.round(11 * root.ui)
            font.weight: Font.Bold
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(36 * root.ui)
            spacing: Math.round(16 * root.ui)

            // the notice
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.host.unlocking ? "▸ THE HUNT RESUMES ▸" : "— THE HUNT IS HELD —"
                color: root.host.unlocking ? root.steel : root.boneA(0.9)
                font.family: root.serif
                font.pixelSize: Math.round(15 * root.ui)
                font.weight: Font.Black
                font.letterSpacing: 7
            }

            // the time, stamped in blacks
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hhmm
                color: root.boneA(0.94)
                font.family: root.serif
                font.pixelSize: Math.round(74 * root.ui)
                font.weight: Font.Black
                font.letterSpacing: 4
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.55)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ENTRY · " + Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                color: root.inkA(0.6)
                font.family: root.serif
                font.pixelSize: Math.round(12 * root.ui)
                font.weight: Font.Bold
                font.letterSpacing: 5
            }

            // double ledger rule
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3
                Rectangle { width: Math.round(240 * root.ui); height: 2; color: root.boneA(0.4) }
                Rectangle { width: Math.round(240 * root.ui); height: 1; color: root.boneA(0.15) }
            }

            // ── the cylinder: a round seats per keystroke ───────────────────
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(12 * root.ui)

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * root.ui)
                    Repeater {
                        model: Math.max(8, Math.min(14, root.host.pwLength))
                        delegate: Item {
                            id: chamber
                            required property int index
                            readonly property bool filled: index < root.host.pwLength
                            width: Math.round(14 * root.ui)
                            height: width
                            // the chamber ring
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: root.ashA(0.9)
                            }
                            // the seated round
                            Rectangle {
                                id: round
                                anchors.centerIn: parent
                                width: parent.width - Math.round(5 * root.ui)
                                height: width
                                radius: width / 2
                                color: root.host.failed ? root.blood : root.boneA(0.9)
                                visible: chamber.filled
                                opacity: root.host.busy ? 0.5 : 1
                                // hammer law: the round slams in, no ease-in
                                onVisibleChanged: if (visible) seat.restart()
                                NumberAnimation {
                                    id: seat
                                    target: round; property: "scale"
                                    from: 1.7; to: 1; duration: 90; easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }

                Text {
                    id: prompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    property bool tick: true
                    text: root.host.failed ? "MISFIRE — STEADY YOUR HAND"
                        : root.host.busy ? "CHECKING THE LEDGER…"
                        : root.host.pwLength > 0 ? "⏎ DROP THE HAMMER"
                        : "LOAD YOUR IRONS"
                    color: root.host.failed ? root.blood : root.inkA(0.55)
                    // the empty prompt ticks hard, a hammer being thumbed
                    opacity: (root.host.pwLength === 0 && !root.host.failed && prompt.tick)
                             || root.host.pwLength > 0 || root.host.failed ? 1 : 0.15
                    font.family: root.serif
                    font.pixelSize: Math.round(11 * root.ui)
                    font.weight: Font.Bold
                    font.letterSpacing: 4
                    Timer {
                        interval: 800; repeat: true
                        running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                        onTriggered: prompt.tick = !prompt.tick
                    }
                }
            }
        }

        // misfire: the poster takes the recoil — stepped knocks, no easing
        Connections {
            target: root.host
            function onFailedChanged() { if (root.host.failed) recoil.restart() }
            function onUnlockingChanged() { if (root.host.unlocking) { muzzle.restart(); partSmoke.fire() } }
        }
        SequentialAnimation {
            id: recoil
            PropertyAction { target: panel; property: "sx"; value: -9 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 7 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: -3 }
            PauseAnimation { duration: 55 }
            PropertyAction { target: panel; property: "sx"; value: 0 }
        }
        property int sx: 0
        transform: Translate { x: panel.sx }
    }

    // whose ledger this is
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * root.ui)
        text: "GUNSMOKE · THE BOUNTY LEDGER KEEPS ITSELF"
        color: root.inkA(0.35)
        font.family: root.serif
        font.pixelSize: Math.round(10 * root.ui)
        font.weight: Font.Bold
        font.letterSpacing: 5
        opacity: root.p
    }

    // ── the hammer falls: one frame of muzzle flash, then smoke ────────────
    Rectangle {
        id: flashRect
        anchors.fill: parent
        color: root.boneA(1)
        opacity: 0
    }
    SequentialAnimation {
        id: muzzle
        PropertyAction { target: flashRect; property: "opacity"; value: 0.55 }
        PauseAnimation { duration: 60 }
        NumberAnimation { target: flashRect; property: "opacity"; to: 0; duration: 420; easing.type: Easing.OutQuad }
    }
    // powder smoke curling up mid-screen as the hunt reopens
    Item {
        id: partSmoke
        x: root.width / 2
        y: root.height * 0.45
        property real t: -1
        visible: t >= 0
        function fire() { smokeAnim.restart() }
        readonly property real tt: Math.max(0, t)
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property real ph: index * 0.3
                x: (index - 1.5) * 26 + Math.sin((partSmoke.tt + ph) * 5) * 12
                y: -partSmoke.tt * (120 + index * 40)
                width: (18 + index * 8) * (1 + partSmoke.tt * 2) * root.ui
                height: width
                radius: width / 2
                color: root.boneA(0.16 * (1 - partSmoke.tt))
            }
        }
        NumberAnimation {
            id: smokeAnim
            target: partSmoke; property: "t"
            from: 0; to: 1; duration: 1100; easing.type: Easing.OutQuad
            onStopped: partSmoke.t = -1
        }
    }
}
