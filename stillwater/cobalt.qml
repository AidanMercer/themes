import QtQuick

// stillwater: the quiet room. Cobalt is where calls happen, so the mirror
// keeps its most restrained face: a whisper of twilight gradient under the
// stripped Teams regions, one low waterline with four dim lamps standing on
// it (doubled beneath, barely), and nothing that moves on its own. A rail
// navigation — chat, calendar, activity — is a single slow glint sliding a
// short way along the line, then stillness again. No loops, no shimmer;
// this backdrop must never distract from a face on the other side.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 577) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property string wordmark: "◦ still water"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real wl: height - 58

            // the evening gradient, very faint, top to waterline
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.04) }
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.skyA(0.05) }
                }
            }
            Rectangle { x: 0; y: bd.wl; width: parent.width; height: 1; color: chrome.skyA(0.16) }

            // four dim lamps, static
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property real lv: 0.25 + chrome.rnd(index * 29 + 7) * 0.4
                    x: Math.round(bd.width * (0.14 + index * 0.24))
                    y: bd.wl
                    Rectangle {
                        x: -1.5; y: -2
                        width: 3; height: 3
                        radius: 1.5
                        color: chrome.lampA(0.2 + 0.4 * lv)
                    }
                    Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(lv * 0.22) }
                }
            }
        }
    }

    // ── rail navigation: one slow glint along the line, then stillness ─────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: glint
                property real t: -1
                visible: t >= 0
                y: ov.height - 58
                x: ov.width * (0.3 + 0.4 * Math.max(0, t))
                opacity: t < 0 ? 0 : Math.sin(Math.max(0, t) * Math.PI)
                Rectangle { x: -2; y: -3; width: 4; height: 4; radius: 2; color: chrome.lampA(0.7) }
                Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(0.25) }
                NumberAnimation {
                    id: glintAnim
                    target: glint; property: "t"
                    from: 0; to: 1; duration: 1300; easing.type: Easing.InOutSine
                    onStopped: glint.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) glintAnim.restart() }
            }
        }
    }
}
