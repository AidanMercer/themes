import QtQuick

// stillwater: soundings. The system monitor is the one place the mirror is
// allowed to be honest about disturbance — the waterline at the foot of the
// window is drawn live, and its CALM is the machine's: an idle CPU leaves a
// dead-straight line (and the painter parks entirely); load makes the line
// waver, higher and choppier as the machine works. Memory pressure lights a
// strand of depth lamps along the line. A re-sort blooms one small ripple; a
// kill is the heavy event — a dusk-rose lamp drops out of the chrome into
// the water, the surface takes a shock, and stills. Chrome + voice only.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real memLoad: host && host.memLoad !== undefined ? host.memLoad : 0

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function roseA(a) { return Qt.rgba(rose.r, rose.g, rose.b, a) }

    // chassis
    readonly property color cardBorder: Qt.alpha(sky, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property string wordmark: "◦ soundings"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real wl: height - 44
            // a kill shocks the surface for a moment
            property real shock: 0

            // the water under the line
            Rectangle {
                x: 0; y: bd.wl
                width: parent.width
                height: parent.height - bd.wl
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ── the living waterline: its unrest IS the CPU ────────────────
            Canvas {
                id: waterline
                anchors.fill: parent
                property real phase: 0
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const wl = bd.wl, W = width
                    const amp = Math.min(6, chrome.load * 7 + bd.shock * 6)
                    ctx.strokeStyle = String(chrome.skyA(0.35))
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    if (amp < 0.25) {
                        ctx.moveTo(0, wl + 0.5)
                        ctx.lineTo(W, wl + 0.5)
                    } else {
                        const ph = waterline.phase
                        ctx.moveTo(0, wl + 0.5)
                        for (let x = 0; x <= W; x += 7) {
                            const y = wl + 0.5
                                + Math.sin(x * 0.045 + ph * 2.4) * amp * 0.6
                                + Math.sin(x * 0.013 - ph * 1.1) * amp * 0.4
                            ctx.lineTo(x, y)
                        }
                    }
                    ctx.stroke()
                    // depth lamps: memory pressure lights them along the line
                    const nl = 8
                    const lit = Math.round(chrome.memLoad * nl)
                    for (let i = 0; i < nl; i++) {
                        const cx = Math.round(W * (0.12 + i * 0.76 / (nl - 1)))
                        const on = i < lit
                        const tone = chrome.memLoad > 0.9 ? chrome.rose : chrome.lamp
                        ctx.fillStyle = on ? String(Qt.rgba(tone.r, tone.g, tone.b, 0.7))
                                           : String(chrome.skyA(0.25))
                        ctx.fillRect(cx - 1.5, wl - 3, 3, 3)
                        if (on) {
                            ctx.fillStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.22))
                            ctx.fillRect(cx - 1, wl + 3, 2, 2)
                        }
                    }
                }
                Component.onCompleted: requestPaint()
            }
            // the painter runs only while there is something to show — a calm
            // machine in a focused window costs one straight line, then parks
            Timer {
                interval: 90
                repeat: true
                running: chrome.awake && bd.visible && (chrome.load > 0.04 || bd.shock > 0.01)
                onTriggered: { waterline.phase += 0.09; waterline.requestPaint() }
            }
            // repaint once when calm returns or memory lamps change
            Connections {
                target: chrome
                function onLoadChanged() { if (chrome.load <= 0.04) waterline.requestPaint() }
                function onMemLoadChanged() { waterline.requestPaint() }
            }

            // ── re-sort: one small ripple on the line ──────────────────────
            Item {
                id: sortRipple
                x: Math.round(bd.width * 0.5)
                y: bd.wl
                property real t: -1
                visible: t >= 0
                Rectangle {
                    anchors.centerIn: parent
                    width: 6 + 90 * Math.max(0, sortRipple.t)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: chrome.lampA(0.4 * (1 - Math.max(0, sortRipple.t)))
                    transform: Scale { origin.y: (6 + 90 * Math.max(0, sortRipple.t)) / 2; yScale: 0.2 }
                }
                NumberAnimation {
                    id: sortAnim
                    target: sortRipple; property: "t"
                    from: 0; to: 1; duration: 1100; easing.type: Easing.OutSine
                    onStopped: sortRipple.t = -1
                }
            }

            // ── a kill: the rose lamp goes into the water ──────────────────
            Item {
                id: casualty
                x: Math.round(bd.width * 0.5)
                property real t: -1
                visible: t >= 0
                y: bd.wl - (1 - Math.min(1, Math.max(0, t) * 1.6)) * 60
                opacity: t < 0.6 ? 1 : (1 - t) * 2.5
                Rectangle { x: -2.5; y: -2.5; width: 5; height: 5; radius: 2.5; color: chrome.rose }
                NumberAnimation {
                    id: killAnim
                    target: casualty; property: "t"
                    from: 0; to: 1; duration: 900; easing.type: Easing.InQuad
                    onStopped: casualty.t = -1
                }
            }
            SequentialAnimation {
                id: shockAnim
                NumberAnimation { target: bd; property: "shock"; to: 1; duration: 500; easing.type: Easing.OutQuad }
                NumberAnimation { target: bd; property: "shock"; to: 0; duration: 2600; easing.type: Easing.InOutSine }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortAnim.restart() }
                function onKillPulseChanged() {
                    if (!chrome.awake) return
                    killAnim.restart()
                    shockAnim.restart()
                }
            }
        }
    }
}
