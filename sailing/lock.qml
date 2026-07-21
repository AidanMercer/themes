import QtQuick
import QtQuick.Effects
import Quickshell

// sailing: bare lock (the bareLock marker tells LockStage we own the chrome).
// The rain and the sea keep playing, but you've stepped inside: the whole
// screen becomes the cabin wall — a darkened, blurred slice of the scene —
// except one large porthole of sharp glass looking back out at the crossing.
// Brass rivets ring the porthole and light up one by one as the passcode is
// typed; a wrong code flares the signal lamp lifebuoy-red. The clock entry
// (this theme's clock grammar) sits upper-left with the vessel wordmark.
// Everything rides host.progress so unlock plays it back.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color buoy:  pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color alarm: pal.magenta
    readonly property color lamp:  pal.amber
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property color glass: pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }
    function buoyA(a)  { return Qt.rgba(buoy.r, buoy.g, buoy.b, a) }

    // porthole geometry — right of center so the log keeps the upper-left sky
    readonly property real cx: root.width * 0.60
    readonly property real cy: root.height * 0.46
    readonly property real pr: Math.min(root.width, root.height) * 0.29

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── the cabin wall: blurred scene, everywhere but the porthole ──────────
    // downscaled live slice of the video → the blur stays cheap at 4K
    ShaderEffectSource {
        id: wallSrc
        sourceItem: root.host.backgroundItem
        live: true
        visible: false
        textureSize: Qt.size(Math.max(1, Math.round(root.width / 4)),
                             Math.max(1, Math.round(root.height / 4)))
    }

    // the mask: opaque wall with a circular pane punched out
    Canvas {
        id: holeMask
        anchors.fill: parent
        visible: false
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#ffffff"
            ctx.fillRect(0, 0, width, height)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(root.cx, root.cy, root.pr, 0, Math.PI * 2)
            ctx.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    ShaderEffectSource {
        id: holeMaskSrc
        sourceItem: holeMask
        visible: false
    }

    Item {
        id: wall
        anchors.fill: parent
        opacity: root.p
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: holeMaskSrc
        }

        MultiEffect {
            anchors.fill: parent
            source: wallSrc
            blurEnabled: true
            blur: 1.0
            blurMax: 42
            brightness: -0.24
            saturation: -0.3
        }
        Rectangle {
            anchors.fill: parent
            color: root.glassA(0.6)
        }
        // plank seams in the cabin wall
        Repeater {
            model: 5
            Rectangle {
                required property int index
                y: Math.round(root.height * (0.12 + index * 0.19))
                width: root.width
                height: 1
                color: root.slateA(0.16)
            }
        }
    }

    // ── the porthole frame ──────────────────────────────────────────────────
    Item {
        id: frame
        x: root.cx - width / 2
        y: root.cy - height / 2
        width: root.pr * 2
        height: root.pr * 2
        opacity: root.p
        scale: 1.04 - 0.04 * root.p

        // outer steel collar
        Rectangle {
            anchors.centerIn: parent
            width: root.pr * 2 + 34
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 17
            border.color: root.glassA(0.92)
        }
        // brass ring
        Rectangle {
            anchors.centerIn: parent
            width: root.pr * 2 + 8
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2.5
            border.color: root.lampA(0.85)
        }
        // inner hairline against the glass
        Rectangle {
            anchors.centerIn: parent
            width: root.pr * 2 - 6
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.paleA(0.22)
        }

        // rain on the pane: sparse droplets, well inside the glass
        Repeater {
            model: 14
            Item {
                required property int index
                readonly property real a: index * 2.399963           // golden angle
                readonly property real rr: root.pr * (0.15 + ((index * 0.6180339) % 1) * 0.68)
                x: root.pr + Math.cos(a) * rr
                y: root.pr + Math.sin(a) * rr
                width: 3; height: 4
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: root.paleA(0.14)
                }
                Rectangle {
                    x: 0.5; y: 0.5; width: 1.2; height: 1.2; radius: 1
                    color: root.paleA(0.4)
                }
            }
        }
        // two drops that occasionally let go and run down the glass
        Repeater {
            model: 2
            Rectangle {
                id: drip
                required property int index
                readonly property real seed: index === 0 ? 0.34 : 0.71
                x: root.pr * 2 * seed
                width: 1.2
                height: 11
                radius: 1
                color: root.paleA(0.30)
                opacity: 0
                SequentialAnimation on y {
                    running: root.p > 0.5
                    loops: Animation.Infinite
                    PauseAnimation { duration: drip.index === 0 ? 4000 : 9500 }
                    ScriptAction { script: drip.opacity = 0.9 }
                    NumberAnimation {
                        from: root.pr * (drip.index === 0 ? 0.55 : 0.4)
                        to: root.pr * 1.5
                        duration: 6500
                        easing.type: Easing.InQuad
                    }
                    ScriptAction { script: drip.opacity = 0 }
                    PauseAnimation { duration: drip.index === 0 ? 7000 : 3500 }
                }
            }
        }
    }

    // ── rivets: the passcode, set into the porthole collar ──────────────────
    // one brass rivet per typed character (12 around the rim), warm-lit as
    // they're set; a wrong code flares them — and the signal lamp — red.
    property real failT: 0
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) failFlash.restart() }
    }
    SequentialAnimation {
        id: failFlash
        NumberAnimation { target: root; property: "failT"; to: 1; duration: 90 }
        NumberAnimation { target: root; property: "failT"; to: 0.25; duration: 260 }
        NumberAnimation { target: root; property: "failT"; to: 1; duration: 90 }
        NumberAnimation { target: root; property: "failT"; to: 0; duration: 700; easing.type: Easing.OutQuad }
    }

    Repeater {
        model: 12
        Item {
            id: rivet
            required property int index
            readonly property real a: -Math.PI / 2 + index * Math.PI / 6
            readonly property bool lit: index < root.host.pwLength
            x: root.cx + Math.cos(a) * (root.pr + 17) - width / 2
            y: root.cy + Math.sin(a) * (root.pr + 17) - height / 2
            width: 9; height: 9
            opacity: root.p

            // warm glow behind a set rivet
            Rectangle {
                anchors.centerIn: parent
                width: 19; height: 19; radius: 9.5
                color: root.failT > 0 ? Qt.rgba(root.alarm.r, root.alarm.g, root.alarm.b, 0.3 * root.failT)
                     : rivet.lit ? root.lampA(0.28) : "transparent"
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 4.5
                color: root.failT > 0 ? root.alarm
                     : rivet.lit ? root.lamp : root.lampA(0.16)
                border.width: 1
                border.color: root.failT > 0 ? root.alarm
                            : rivet.lit ? root.lampA(1) : root.lampA(0.4)
                scale: root.host.busy && rivet.lit ? 0.7 : 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 240 } }
            }
        }
    }

    // the signal lamp: a red warning flare high on the cabin wall on failure
    Rectangle {
        x: root.cx - width / 2
        y: root.cy - root.pr - 130
        width: 260; height: 260; radius: 130
        color: root.alarm
        opacity: 0.16 * root.failT
        scale: 0.8 + 0.4 * root.failT
    }

    // ── the log entry, upper-left (this theme's clock grammar) ──────────────
    Column {
        x: Math.round(root.width * 0.05)
        y: Math.round(root.height * 0.12)
        spacing: 8
        opacity: root.p
        transform: Translate { x: -18 * (1 - root.p) }

        Row {
            spacing: 9
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5; radius: 2.5
                color: root.lamp
            }
            Text {
                text: "M.V. THROUGH SILENCE"
                color: root.duskA(0.9)
                font.family: root.mono
                font.pixelSize: Math.round(12 * root.ui)
                font.letterSpacing: 5
            }
        }
        Text {
            id: lockTime
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.pale
            font.family: root.serif
            font.pixelSize: Math.round(88 * root.ui)
            font.weight: Font.Light
            font.letterSpacing: 4
        }
        Item {
            width: lockTime.width * root.p
            height: 12
            clip: true
            Rectangle { y: 2; width: lockTime.width; height: 1; color: root.paleA(0.5) }
            Rectangle { y: 8; width: lockTime.width; height: 1; color: root.slateA(0.7) }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: index === 3 ? lockTime.width - 2 : Math.round(lockTime.width * index / 3)
                    y: 1
                    width: 2; height: 9
                    color: index === 0 ? root.buoy : root.paleA(0.6)
                }
            }
        }
        Text {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM")
            color: root.duskA(0.8)
            font.family: root.mono
            font.pixelSize: Math.round(13 * root.ui)
            font.letterSpacing: 4
        }
    }

    // prompt under the porthole
    Text {
        x: root.cx - width / 2
        y: root.cy + root.pr + 44
        opacity: root.p
        text: root.host.failed ? "wrong password"
            : root.host.busy ? "checking…"
            : root.host.pwLength > 0 ? ""
            : "type your password"
        color: root.host.failed ? root.alarm : root.paleA(0.7)
        font.family: root.serif
        font.pixelSize: Math.round(15 * root.ui)
        font.italic: true
        font.letterSpacing: 2
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}
