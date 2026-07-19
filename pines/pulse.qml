import QtQuick

// pines: pulse is the STORM GLASS — the instrument the lookout taps when the
// weather turns. The house chassis frames the gauges, and the fog on the
// glass IS the machine's weather: the drift thickens as host.load climbs,
// so an idle box sits behind clear glass and a pinned one disappears into
// weather. A re-sort taps the glass (a small breath); actually killing a
// process is the storm — a heavy breath of condensation flushed ember red.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "▵ STORM GLASS"

    readonly property Component backdrop: Component {
        Item {
            // ── chassis: benchmark + bearing rule + lamp corner ticks ──────
            Canvas {
                id: chassis
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, inset = 8
                    ctx.strokeStyle = chrome.pal.cyan
                    ctx.globalAlpha = 0.6
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(inset + 5, inset)
                    ctx.lineTo(inset + 10, inset + 8)
                    ctx.lineTo(inset, inset + 8)
                    ctx.closePath()
                    ctx.stroke()
                    ctx.globalAlpha = 0.35
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w * 0.4, inset + 4)
                    ctx.stroke()
                    for (let i = 1; i <= 5; i++) {
                        const x = inset + 18 + (w * 0.4 - inset - 18) * i / 6
                        ctx.beginPath()
                        ctx.moveTo(x, inset + (i % 2 ? 2 : 0.5)); ctx.lineTo(x, inset + 4)
                        ctx.stroke()
                    }
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                    ctx.lineTo(w - inset - 14, h - inset)
                    ctx.stroke()
                }
            }

            // the machine's weather: fog density rides the load
            ShaderEffect {
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                property real ember: 0
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                opacity: 0.35 + 0.65 * Math.min(1, chrome.load)
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }
        }
    }

    // ── taps and storms above the gauges ───────────────────────────────────
    readonly property Component overlay: Component {
        ShaderEffect {
            id: breath
            property real time: 0
            property real burst: 0
            property real ember: 0
            fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
            visible: burst > 0.01   // transient by design
            NumberAnimation {
                id: sortTap
                target: breath; property: "burst"
                from: 0.35; to: 0; duration: 500
                easing.type: Easing.OutQuad
            }
            SequentialAnimation {
                id: killStorm
                PropertyAction { target: breath; property: "ember"; value: 1 }
                ParallelAnimation {
                    NumberAnimation { target: breath; property: "burst"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                    NumberAnimation { target: breath; property: "ember"; from: 1; to: 0; duration: 1000; easing.type: Easing.OutQuad }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortTap.restart() }
                function onKillPulseChanged() { if (chrome.awake) killStorm.restart() }
            }
        }
    }
}
