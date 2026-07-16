import QtQuick
import QtQuick.Particles

// vinland: the open sea — every page is a stretch of unknown water, every
// navigation a heading struck westward. the page hides the middle of the
// window, so the night lives in the chrome bands: aurora over the tab strip
// (the shader keeps to the sky on its own), frost under the status bar, and
// paired knife-notch ticks down both margins — the latitude scale of a skin
// chart. a new heading sights the north star at the bow and strikes a gold
// course-line westward along the top rule.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon=ice, cyan=gold, magenta=blood)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.22)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "❄ westward"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // aurora over the tab strip — gone by mid-window, where the page is
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("aurora.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // frost mist under the status bar
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 110
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.07) }
                }
            }

            // sparse snow — it only surfaces where a page lets the night through
            ParticleSystem {
                id: sys
                running: true
                paused: !chrome.awake || !bd.visible
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 1.4
                lifeSpan: 22000
                velocity: AngleDirection {
                    angle: 90; magnitude: 26
                    angleVariation: 6; magnitudeVariation: 10
                }
            }
            Wander { system: sys; xVariance: 40; pace: 30 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: Math.random() < 0.3 ? 3 : 2
                    height: width; radius: width / 2
                    color: Qt.alpha(chrome.pal.text, 0.16 + Math.random() * 0.22)
                }
            }

            // the chart's latitude scale — paired knife-notches carved down
            // both margins, leaned the way the overview ring leans its cuts
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.28
                    ctx.lineWidth = 1
                    for (let y = 96; y < height - 60; y += 96) {
                        for (const x0 of [5, width - 12]) {
                            ctx.beginPath()
                            ctx.moveTo(x0, y); ctx.lineTo(x0 + 7, y - 3)
                            ctx.moveTo(x0, y + 5); ctx.lineTo(x0 + 7, y + 2)
                            ctx.stroke()
                        }
                    }
                }
            }

            // the gold course-line — struck westward along the top rule on
            // each new heading, then gone; rests invisible between voyages
            Rectangle {
                id: course
                width: 56; height: 1
                y: 34
                rotation: -6
                color: Qt.alpha(chrome.pal.cyan, 0.9)
                opacity: 0
            }

            // the north star at the bow, over the tab strip's end
            Canvas {
                id: star
                width: 44; height: 44
                anchors { right: parent.right; top: parent.top; rightMargin: 22; topMargin: 12 }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineCap = "round"
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.moveTo(c, c - 16); ctx.lineTo(c, c + 16)
                    ctx.moveTo(c - 12, c); ctx.lineTo(c + 12, c)
                    ctx.stroke()
                    ctx.globalAlpha = 0.9
                    ctx.fillStyle = chrome.pal.text
                    ctx.beginPath(); ctx.arc(c, c, 1.6, 0, Math.PI * 2); ctx.fill()
                }
                Component.onCompleted: requestPaint()
            }

            // the heading: star glints, course-line runs westward — one shot
            ParallelAnimation {
                id: glint
                SequentialAnimation {
                    NumberAnimation { target: star; property: "scale"; to: 1.25; duration: 450; easing.type: Easing.OutQuad }
                    NumberAnimation { target: star; property: "scale"; to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
                }
                SequentialAnimation {
                    PropertyAction { target: course; property: "opacity"; value: 0.9 }
                    ParallelAnimation {
                        NumberAnimation { target: course; property: "x"; from: bd.width - 110; to: bd.width * 0.32; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { target: course; property: "opacity"; from: 0.9; to: 0; duration: 1000; easing.type: Easing.InQuad }
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) glint.restart() }
            }
        }
    }
}
