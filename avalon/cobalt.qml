import QtQuick

// avalon: the round table — the client where the realm's business is spoken,
// so the meadow keeps its manners. behind the glass the sun-bokeh drifts at
// half its usual pace and a few petals lie settled along the sill, exactly
// where they fell; the only motion a navigation earns is three buttercup
// petals let go beneath the titlebar, falling a short way and gone. no
// storms in the council chamber. same grammar as beryl.qml, minus the frame.
Item {
    id: chrome

    required property var pal
    property var host: null    // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property string wordmark: "⚘ round table"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // sun-bokeh at half pace — surfacing through the stripped Teams
            // regions, and faintly through the translucent bars
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("bokeh.frag.qsb")
                opacity: 0.6
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 1800; duration: 3600000   // half the meadow's usual drift
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // moss on the sill, under the status line
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 160
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                }
            }

            // petals settled where they fell — a still life along the bottom
            // edge, painted once and left alone
            Canvas {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 30
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                function hash(n) { const v = Math.sin(n) * 43758.5453; return v - Math.floor(v) }
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    ctx.reset()
                    for (let i = 0; i < 7; i++) {
                        const r1 = hash(i * 12.9898 + 3.7), r2 = hash(i * 78.233 + 1.3)
                        const px = w * (0.06 + 0.88 * r1)
                        const py = h - 4 - r2 * 10
                        ctx.save()
                        ctx.translate(px, py)
                        ctx.rotate(r2 * Math.PI)
                        ctx.scale(1, 0.6)
                        ctx.beginPath()
                        ctx.arc(0, 0, 3.4, 0, Math.PI * 2)
                        ctx.fillStyle = r1 < 0.6 ? chrome.pal.cyan : chrome.pal.text
                        ctx.globalAlpha = 0.16 + r2 * 0.10
                        ctx.fill()
                        ctx.restore()
                    }
                }
            }
        }
    }

    // ── a rail switch lets three petals go beneath the titlebar — brief and
    // quiet, and then the chamber is still again ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            property real drop: 0       // 0..1, driven only by the one-shot fall
            property real seed: 0.37    // rerolled each fire, so the petals never repeat
            function ph(n) { const v = Math.sin(seed * 97 + n * 13.7) * 43758.5453; return v - Math.floor(v) }

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    // staggered release: each petal lets go a beat after the last
                    readonly property real p: Math.max(0, Math.min(1, (ov.drop - index * 0.12) / 0.76))
                    readonly property real e: 1 - (1 - p) * (1 - p)    // petals catch the air
                    width: 7; height: 5; radius: 2.5
                    visible: p > 0 && p < 1
                    x: ov.width * (0.15 + 0.7 * ov.ph(index + 1)) + Math.sin(p * 5 + index) * 12
                    y: 38 + ov.ph(index + 5) * 22 + e * (110 + ov.ph(index + 9) * 50)
                    rotation: ov.ph(index + 3) * 360 + p * 150 * (index % 2 === 0 ? 1 : -1)
                    opacity: 0.8 * Math.min(1, p * 6) * (1 - p)
                    color: index === 1 ? Qt.alpha(chrome.pal.text, 0.70)   // one cream
                                       : Qt.alpha(chrome.pal.cyan, 0.75)   // two buttercup
                }
            }

            SequentialAnimation {
                id: fall
                ScriptAction { script: ov.seed = Math.random() }
                NumberAnimation { target: ov; property: "drop"; from: 0; to: 1; duration: 1100 }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) fall.restart() }
            }
        }
    }
}
