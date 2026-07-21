import QtQuick
import Quickshell

// stillwater: bare lock (the bareLock marker tells LockStage we own the
// chrome). Locking doesn't dim this desktop into frosted glass — the mirror
// simply keeps the evening. The video stays sharp and full-bleed; the sky
// darkens a shade while the water keeps its light. The time surfaces at
// center, feet on the wallpaper's real horizon, doubled below by the mirror
// shader. The passcode is a row of floating lamps on the near water: each
// keystroke lights one and its streak blooms; a wrong code flushes them
// dusk-rose and stirs the whole reflection; the moment the code lands, the
// water takes everything back down into the line and the evening lets you
// through. Typing/Enter route through the shell.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    readonly property real hzY: Math.round(root.height * 0.527)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // departure: the water absorbs everything on unlock
    readonly property real sink: host.unlocking ? 1 : 0
    property real sinkT: sink
    Behavior on sinkT { NumberAnimation { duration: 700; easing.type: Easing.InQuad } }

    // ── the sky dims; the water keeps the light ────────────────────────────
    Rectangle {
        x: 0; y: 0
        width: parent.width
        height: root.hzY
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.01, 0.04, 0.10, 0.42) }
            GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.04, 0.10, 0.10) }
        }
    }
    Rectangle {
        x: 0; y: root.hzY
        width: parent.width
        height: parent.height - root.hzY
        color: Qt.rgba(0.01, 0.04, 0.10, 0.10)
        opacity: root.p
    }

    // ── the time, standing on the horizon ──────────────────────────────────
    Item {
        id: ensemble
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.hzY - height
        width: stand.width
        height: stand.height
        scale: root.ui
        transformOrigin: Item.Bottom
        opacity: root.p * (1 - root.sinkT)

        Item {
            id: stand
            width: digits.width
            height: dateText.height + 12 + digits.height
            // rising out of the seam as the lock engages; sinking on unlock
            transform: Translate { y: (1 - root.p) * 40 + root.sinkT * stand.height * 0.6 }

            Text {
                id: dateText
                x: Math.round((digits.width - width) / 2)
                y: 0
                text: Qt.formatDateTime(clock.date, "dddd · d MMMM").toUpperCase()
                color: root.skyA(0.9)
                font.family: root.mono
                font.pixelSize: 13
                font.letterSpacing: 7
            }
            Row {
                id: digits
                y: dateText.height + 12
                spacing: 3
                Repeater {
                    model: 5
                    Text {
                        required property int index
                        readonly property bool isColon: index === 2
                        text: root.hhmm.charAt(index)
                        color: root.lamp
                        font.family: root.serif
                        font.pixelSize: 112
                        font.weight: Font.Light
                        opacity: isColon ? colonBreath.o : 1
                    }
                }
            }
            QtObject { id: colonBreath; property real o: 1 }
            SequentialAnimation {
                running: root.p > 0.5 && !root.host.unlocking
                loops: Animation.Infinite
                NumberAnimation { target: colonBreath; property: "o"; to: 0.45; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { target: colonBreath; property: "o"; to: 1.0; duration: 2800; easing.type: Easing.InOutSine }
            }
        }

        // the waterline under the digits
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -1
            x: -40
            width: stand.width + 80
            height: 1
            opacity: root.p
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: root.skyA(0.55) }
                GradientStop { position: 0.8; color: root.skyA(0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // the mirror
        ShaderEffectSource {
            id: standSrc
            sourceItem: stand
            hideSource: false
            live: true
            visible: false
        }
        ShaderEffect {
            id: mirror
            anchors.top: parent.bottom
            anchors.topMargin: 2
            width: stand.width
            height: Math.round(stand.height * 0.8)
            fragmentShader: Qt.resolvedUrl("mirror.frag.qsb")
            property var source: standSrc
            property real time: 0
            property real stir: 0
            property real strength: 0.55 * root.p
            property color water: Qt.rgba(0.06, 0.19, 0.34, 1)
        }
        NumberAnimation {
            target: mirror; property: "time"
            from: 0; to: 120; duration: 120000
            loops: Animation.Infinite
            running: mirror.stir > 0.001 && root.p > 0
        }
        SequentialAnimation {
            id: stirAnim
            NumberAnimation { target: mirror; property: "stir"; to: 1; duration: 250; easing.type: Easing.OutQuad }
            NumberAnimation { target: mirror; property: "stir"; to: 0; duration: 4600; easing.type: Easing.InOutSine }
        }
    }

    // ── the passcode: floating lamps on the near water ─────────────────────
    Column {
        id: tray
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.hzY + Math.round(110 * root.ui)
        spacing: Math.round(22 * root.ui)
        opacity: root.p * (1 - root.sinkT)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(20 * root.ui)
            Repeater {
                model: Math.max(8, Math.min(14, root.host.pwLength))
                delegate: Item {
                    id: socket
                    required property int index
                    readonly property bool filled: index < root.host.pwLength
                    readonly property color tone: root.host.failed ? root.rose : root.lamp
                    width: Math.round(10 * root.ui)
                    height: Math.round(30 * root.ui)

                    // the empty mooring: a dark ring on the water
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: parent.width
                        height: parent.width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: socket.filled ? socket.tone : root.slateA(0.8)
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                    }
                    // the lamp lit by a keystroke
                    Rectangle {
                        id: coin
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(2 * root.ui)
                        width: parent.width - Math.round(4 * root.ui)
                        height: width
                        radius: width / 2
                        color: socket.tone
                        visible: socket.filled
                        opacity: root.host.busy ? 0.5 : 1
                        onVisibleChanged: if (visible) surfaceAnim.restart()
                        NumberAnimation {
                            id: surfaceAnim
                            target: coin; property: "scale"
                            from: 0.3; to: 1; duration: 260; easing.type: Easing.OutSine
                        }
                    }
                    // its streak, blooming beneath
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.width + Math.round(5 * root.ui)
                        spacing: 3
                        visible: socket.filled
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round((4 - index) * root.ui)
                                height: 2
                                color: Qt.rgba(socket.tone.r, socket.tone.g, socket.tone.b,
                                               0.4 - index * 0.12)
                            }
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
                : root.host.busy ? "…"
                : root.host.unlocking ? "unlocking"
                : root.host.pwLength > 0 ? "⏎ when ready"
                : "type to unlock"
            textFormat: Text.PlainText
            color: root.host.failed ? root.rose : root.skyA(0.85)
            opacity: (root.host.pwLength === 0 && !root.host.failed && !prompt.tick) ? 0.3 : 1
            Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
            font.family: root.mono
            font.pixelSize: Math.round(12 * root.ui)
            font.letterSpacing: 4
            Timer {
                interval: 2400; repeat: true
                running: root.p > 0.9 && root.host.pwLength === 0 && !root.host.unlocking
                onTriggered: prompt.tick = !prompt.tick
            }
        }
    }

    // a wrong code stirs the whole mirror; so does the way out
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) stirAnim.restart() }
        function onUnlockingChanged() { if (root.host.unlocking) stirAnim.restart() }
    }

    // the theme's signature
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(34 * root.ui)
        text: "STILL WATER"
        color: root.skyA(0.4)
        font.family: root.mono
        font.pixelSize: Math.round(10 * root.ui)
        font.letterSpacing: 5
        opacity: root.p * (1 - root.sinkT)
    }
}
