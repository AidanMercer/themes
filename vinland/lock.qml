import QtQuick
import QtQuick.Effects
import Quickshell

// vinland: bare lock (the bareLock marker tells LockStage we own the chrome).
// The video stays full-bleed and sharp; as the lock engages the night deepens
// at the edges and a band of frost-mist rises from the horizon — a blurred
// slice of the wallpaper under night glass, its frost line drawing outward.
// The time hangs centered in the sky under the runic wordmark; the passcode
// is a row of gold stars set into the mist. Unlock plays it all back.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color night: pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string serif: "Noto Serif Display"
    function snowA(a)  { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)   { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function nightA(a) { return Qt.rgba(night.r, night.g, night.b, a) }

    readonly property real mistH: Math.round(root.height * 0.32)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // the night deepens at the edges as the lock engages
    Canvas {
        id: vignette
        anchors.fill: parent
        opacity: root.p * 0.75
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = ctx.createRadialGradient(width / 2, height / 2, height * 0.28,
                                               width / 2, height / 2, height * 0.85)
            g.addColorStop(0, Qt.rgba(root.night.r, root.night.g, root.night.b, 0))
            g.addColorStop(1, Qt.rgba(root.night.r, root.night.g, root.night.b, 0.62))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
        Connections {
            target: root.pal
            function onGlassChanged() { vignette.requestPaint() }
        }
    }

    // the live video (or still), re-rendered so the mist can blur its slice
    ShaderEffectSource {
        id: slice
        sourceItem: root.host.backgroundItem
        sourceRect: Qt.rect(0, root.height - root.mistH, root.width, root.mistH)
        live: true
        visible: false
    }

    // ── the frost-mist band along the horizon ────────────────────────────────
    Item {
        id: mist
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.mistH
        opacity: root.p

        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 42
            brightness: -0.10
            saturation: -0.18
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.nightA(0.30) }
                GradientStop { position: 1.0; color: root.nightA(0.68) }
            }
        }
        // the frost line, drawing outward from the middle as the lock engages
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * root.p
            height: 1
            color: root.iceA(0.38)
        }

        // snow sifting down through the mist
        Repeater {
            model: 8
            Rectangle {
                id: fleck
                required property int index
                readonly property real seed: (index * 0.61803) % 1
                width: (2 + seed * 2.5) * root.ui
                height: width
                radius: width / 2
                color: root.snowA(0.28 + seed * 0.25)
                x: mist.width * ((seed * 7.13) % 0.94 + 0.03)
                opacity: root.p * 0.8

                NumberAnimation on y {
                    running: root.p > 0.2
                    loops: Animation.Infinite
                    from: -20 - fleck.seed * mist.height * 0.5
                    to: mist.height + 20
                    duration: 17000 + fleck.seed * 21000
                }
            }
        }
    }

    // ── the sky: wordmark, time, date ────────────────────────────────────────
    Column {
        id: skyBlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.14)
        spacing: 16
        opacity: root.p
        transform: Translate { y: -18 * (1 - root.p) }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ᚹᛁᚾᛚᚨᚾᛞ"
            color: root.iceA(0.78)
            font.family: "Noto Sans Runic"
            font.pixelSize: Math.round(14 * root.ui)
            font.letterSpacing: 10
        }
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.snow
            font.family: root.serif
            font.pixelSize: Math.round(96 * root.ui)
            font.weight: Font.Medium
            font.letterSpacing: 3
        }
        // carved stave with a gold star at its heart
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: timeText.width
            height: 13

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * root.p
                height: 1
                color: root.iceA(0.40)
            }
            Canvas {
                id: staveStar
                anchors.centerIn: parent
                width: 13; height: 13
                scale: 0.6 + 0.4 * root.p
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, R = width / 2
                    ctx.beginPath()
                    ctx.moveTo(c, c - R)
                    ctx.quadraticCurveTo(c, c, c + R, c)
                    ctx.quadraticCurveTo(c, c, c, c + R)
                    ctx.quadraticCurveTo(c, c, c - R, c)
                    ctx.quadraticCurveTo(c, c, c, c - R)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.95)
                    ctx.fill()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { staveStar.requestPaint() }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text {
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                color: root.snowA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: Math.round(12 * root.ui)
                font.weight: Font.Medium
                font.letterSpacing: 5
            }
            Rectangle {
                width: 4; height: 4
                rotation: 45
                color: root.goldA(0.85)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                color: root.snowA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: Math.round(12 * root.ui)
                font.weight: Font.Medium
                font.letterSpacing: 5
            }
        }
    }

    // ── passcode: gold stars set into the mist ───────────────────────────────
    Column {
        id: passArea
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.80)
        spacing: 18
        opacity: root.p

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            opacity: root.host.pwLength > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Repeater {
                model: Math.max(root.host.pwLength, 1)
                Canvas {
                    id: dotStar
                    width: Math.round(11 * root.ui); height: width
                    opacity: index < root.host.pwLength ? 1 : 0
                    scale: root.host.busy ? 0.65 : 1
                    Behavior on scale { NumberAnimation { duration: 220 } }
                    property color tint: root.host.failed ? root.rose : root.gold
                    onTintChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const c = width / 2, R = width / 2
                        ctx.beginPath()
                        ctx.moveTo(c, c - R)
                        ctx.quadraticCurveTo(c, c, c + R, c)
                        ctx.quadraticCurveTo(c, c, c, c + R)
                        ctx.quadraticCurveTo(c, c, c - R, c)
                        ctx.quadraticCurveTo(c, c, c, c - R)
                        ctx.closePath()
                        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.95)
                        ctx.fill()
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.host.pwLength === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            text: root.host.failed ? "wrong" : "enter passcode"
            color: root.host.failed ? root.rose : root.snowA(0.45)
            font.family: root.serif
            font.pixelSize: Math.round(14 * root.ui)
            font.italic: true
            font.weight: Font.Medium
            font.letterSpacing: 2
        }
    }
    // wrong password: the stars flinch
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) shake.restart() }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -9; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -5; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        opacity: root.p
        text: "far to the west, beyond the sea"
        color: root.snowA(0.30)
        font.family: root.serif
        font.pixelSize: Math.round(11 * root.ui)
        font.italic: true
        font.weight: Font.Medium
        font.letterSpacing: 3
    }
}
