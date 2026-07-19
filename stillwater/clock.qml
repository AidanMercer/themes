import QtQuick
import Quickshell

// stillwater: the time stands on the water. Thin serif digits parked in the
// empty left sky, their feet exactly on the wallpaper's real horizon line
// (y ≈ 0.527), and below the line the mirror answers: an inverted, dimmed,
// faintly broken reflection rendered by the theme's mirror shader. At rest
// the water is dead calm — the reflection is a static image costing nothing.
// When the minute turns, one ripple ring blooms on the line under the colon
// and the reflection stirs for a few seconds, then stills again. Boot-in is
// the house law: the digits rise out of the seam, reflection growing in
// step. Click-through scenery; reads over the lock blur too (not used there
// — the lock is bare — but the law holds).
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or a fullscreen window covers the monitor
    property bool occluded: false

    readonly property color lamp: pal.neon       // distant-light warm white
    readonly property color sky: pal.cyan        // twilight blue
    readonly property color rose: pal.magenta    // dusk rose
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)   { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // the wallpaper's real waterline
    readonly property real hzY: Math.round(root.height * 0.527)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // boot: rise out of the seam
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1600; easing.type: Easing.OutCubic }

    Item {
        id: ensemble
        x: Math.round(root.width * 0.07)
        y: root.hzY - height          // feet on the line
        width: stand.width
        height: stand.height
        scale: pal.uiScale
        transformOrigin: Item.BottomLeft

        // ── everything above the waterline ─────────────────────────────────
        Item {
            id: stand
            width: digits.width
            height: dateText.height + 10 + digits.height + 3
            // rising out of the water: sunk at boot, surfacing
            transform: Translate { y: (1 - root.bootT) * 26 }
            opacity: 0.25 + 0.75 * root.bootT

            Text {
                id: dateText
                x: Math.round((digits.width - width) / 2)
                y: 0
                text: Qt.formatDateTime(clock.date, "dddd · d MMMM").toUpperCase()
                color: root.skyA(0.85)
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 6
            }

            Row {
                id: digits
                y: dateText.height + 10
                spacing: 2
                Repeater {
                    model: 5
                    Text {
                        required property int index
                        readonly property bool isColon: index === 2
                        text: root.hhmm.charAt(index)
                        color: isColon ? root.lampA(0.9) : root.lamp
                        font.family: root.serif
                        font.pixelSize: 88
                        font.weight: Font.Light
                        // the colon breathes — the only resting motion allowed
                        opacity: isColon ? colonBreath.o : 1
                    }
                }
            }
            QtObject {
                id: colonBreath
                property real o: 1
            }
            SequentialAnimation {
                running: !root.occluded && root.visible
                loops: Animation.Infinite
                NumberAnimation { target: colonBreath; property: "o"; to: 0.45; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { target: colonBreath; property: "o"; to: 1.0; duration: 2800; easing.type: Easing.InOutSine }
            }
        }

        // the waterline itself — a hairline dying away at both ends
        Rectangle {
            id: line
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -1
            x: -26
            width: stand.width + 52
            height: 1
            opacity: root.bootT
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: root.skyA(0.5) }
                GradientStop { position: 0.8; color: root.skyA(0.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── the mirror ─────────────────────────────────────────────────────
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
            property real strength: 0.5 * root.bootT
            property color water: Qt.rgba(0.06, 0.19, 0.34, 1)
        }
        // the water only moves while stirred; at stir 0 nothing repaints
        NumberAnimation {
            target: mirror; property: "time"
            from: 0; to: 120; duration: 120000
            loops: Animation.Infinite
            running: mirror.stir > 0.001 && !root.occluded
        }
        SequentialAnimation {
            id: stirAnim
            NumberAnimation { target: mirror; property: "stir"; to: 1; duration: 350; easing.type: Easing.OutQuad }
            NumberAnimation { target: mirror; property: "stir"; to: 0; duration: 5200; easing.type: Easing.InOutSine }
        }

        // ── the minute turns: one ripple ring on the line ──────────────────
        Item {
            id: ripple
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            x: Math.round(stand.width / 2)
            property real t: -1
            visible: t >= 0
            Rectangle {
                anchors.centerIn: parent
                width: 8 + 150 * Math.max(0, ripple.t)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: root.lampA(0.55 * (1 - Math.max(0, ripple.t)))
                transform: Scale { origin.y: (8 + 150 * Math.max(0, ripple.t)) / 2; yScale: 0.22 }
            }
            NumberAnimation {
                id: rippleAnim
                target: ripple; property: "t"
                from: 0; to: 1; duration: 1900; easing.type: Easing.OutSine
                onStopped: ripple.t = -1
            }
        }
        Connections {
            target: clock
            function onDateChanged() {
                if (root.occluded || root.bootT < 1) return
                rippleAnim.restart()
                stirAnim.restart()
            }
        }
    }
}
