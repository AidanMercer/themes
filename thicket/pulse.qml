import QtQuick

// thicket: the brush tenses — pulse is where you feel the thicket's own
// body. Two clusters of leaves hold the window's flanks, and they LEAN with
// the machine: at idle they hang loose in shadow grey-green; as host.load
// climbs they tense — angling up, flushing through dapple amber toward
// ember — pure bindings, no clock, so a quiet machine is a dead-still
// window. Re-sorting the table is a light rustle along the footer seam.
// A kill is the heavy event: the window flashes ember-red for a breath and
// every leaf snaps flat — the brush goes still around a death. Chrome +
// voice only; the gauges stay pulse's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real memLoad: host && host.memLoad !== undefined ? host.memLoad : 0

    readonly property color ember: pal.neon
    readonly property color emberRed: pal.magenta
    readonly property color dapple: pal.amber
    function emberA(a) { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function leafA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 991) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }
    // shadow → dapple → ember as v rises
    function tenseColor(v, a) {
        const c = v < 0.5
            ? Qt.tint(pal.dim, Qt.rgba(dapple.r, dapple.g, dapple.b, v * 2 * 0.6))
            : Qt.tint(dapple, Qt.rgba(ember.r, ember.g, ember.b, (v - 0.5) * 2 * 0.8))
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // chassis: foliage glass, leaf-dark lip
    readonly property color cardBorder: Qt.alpha(pal.dim, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "❧ heartbeat"

    // the kill: the brush goes still for a moment (backdrop leaves read this)
    property real stillT: 0
    NumberAnimation {
        id: goStill
        target: chrome; property: "stillT"
        from: 1; to: 0; duration: 1400
        easing.type: Easing.OutQuad
    }
    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        function onKillPulseChanged() { if (chrome.awake) goStill.restart() }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // ── the flank clusters: leaves that tense with the machine ──────
            // left flank reads CPU, right flank reads MEM
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    readonly property bool leftSide: index < 7
                    readonly property real v: (leftSide ? chrome.load : chrome.memLoad) * (1 - chrome.stillT)
                    readonly property real f: leftSide ? index / 7 : (index - 7) / 5
                    readonly property real j: chrome.rnd(index * 13 + 1)
                    x: leftSide ? -3 : bd.width - width + 3
                    y: bd.height * (0.15 + f * 0.7) + (j - 0.5) * 24
                    width: 16 + j * 10
                    height: 5 + j * 2.5
                    radius: height / 2
                    // hangs at rest, tenses upward with load — a spring binding
                    rotation: (leftSide ? 1 : -1) * (28 - v * 62 - j * 8)
                    color: chrome.tenseColor(Math.min(1, v * (0.75 + j * 0.5)), 0.8)
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }

            // faint stems the clusters grow from
            Rectangle { x: 4; y: bd.height * 0.12; width: 1; height: bd.height * 0.76; color: chrome.leafA(0.35) }
            Rectangle { x: bd.width - 5; y: bd.height * 0.12; width: 1; height: bd.height * 0.76; color: chrome.leafA(0.35) }
        }
    }

    readonly property Component overlay: Component {
        Item {
            id: ov

            // ── the kill flash: one ember-red breath over everything ────────
            Rectangle {
                id: killGlow
                anchors.fill: parent
                color: chrome.emberRed
                opacity: 0
                SequentialAnimation {
                    id: flash
                    NumberAnimation { target: killGlow; property: "opacity"; to: 0.16; duration: 90 }
                    NumberAnimation { target: killGlow; property: "opacity"; to: 0; duration: 700; easing.type: Easing.OutQuad }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onKillPulseChanged() { if (chrome.awake) flash.restart() }
                }
            }

            // ── the sort rustle: a few leaves flick along the footer seam ───
            Item {
                id: scatter
                property real t: -1
                visible: t >= 0
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real ph: index * 0.12
                        readonly property real k: Math.max(0, Math.min(1, scatter.t - ph))
                        x: -20 + (ov.width + 40) * k
                        y: ov.height - 34 + index * 5 + Math.sin(k * Math.PI * 2 + index * 2) * 5
                        width: 7 - index; height: 3; radius: 1.5
                        rotation: k * 440 * (index % 2 === 0 ? 1 : -1)
                        opacity: scatter.t < 0 ? 0 : (k <= 0 || k >= 1 ? 0 : 0.75)
                        color: index === 1 ? "rgba(35,66,58,0.9)" : Qt.rgba(0.05, 0.08, 0.07, 0.9)
                    }
                }
                NumberAnimation {
                    id: scatterAnim
                    target: scatter; property: "t"
                    from: 0; to: 1.36; duration: 640
                    easing.type: Easing.OutQuad
                    onStopped: scatter.t = -1
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onSortIdChanged() { if (chrome.awake) scatterAnim.restart() }
                }
            }
        }
    }
}
