import QtQuick

// gunsmoke: ledger chrome for beryl — THE WIRE. The browser is the telegraph
// office: a telegraph line runs the seam under the tab strip, insulator dots
// riding it like poles marching into the fog, and every committed navigation
// sends a PULSE down the wire — one bright bone spark sliding the seam with
// a morse trail thinning behind it (the page turn, spoken in telegraphy).
// A small fog bank pools behind the status bar corner. The page owns the
// window's center; all chrome lives in the bands. Everything holds still
// when you look away.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function ashA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // chassis: paper corners, bone hairline
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.3)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property string wordmark: "—·— THE WIRE"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the telegraph line on the seam, insulators marching into the fog
            Rectangle {
                y: chrome.seamY
                x: 10
                width: bd.width - 20
                height: 1
                color: chrome.ashA(0.55)
            }
            Row {
                y: chrome.seamY - 2
                x: 26
                spacing: 84
                Repeater {
                    model: Math.max(2, Math.ceil(bd.width / 88))
                    Rectangle {
                        required property int index
                        width: 4; height: 4; radius: 2
                        color: chrome.ashA(0.9)
                        // the far poles thin into the fog
                        opacity: 1 - (index / Math.max(1, Math.ceil(bd.width / 88))) * 0.5
                    }
                }
            }

            // fog pooled behind the status bar's far corner
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Math.min(260, bd.width * 0.3)
                height: 30
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.steelA(0.07) }
                }
            }

            // corner rivets, top band
            Rectangle { x: 5; y: 5; width: 3; height: 3; radius: 1.5; color: chrome.boneA(0.38) }
            Rectangle { x: bd.width - 8; y: 5; width: 3; height: 3; radius: 1.5; color: chrome.boneA(0.38) }
        }
    }

    // ── every navigation, a pulse down the wire ─────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: pulse
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                y: chrome.seamY - 2

                // the spark
                Rectangle {
                    x: pulse.tt * ov.width - 2
                    width: 5; height: 5; radius: 2.5
                    color: chrome.boneA(1)
                }
                // the morse trail thinning behind it: dash dot dash
                Row {
                    x: pulse.tt * ov.width - 46
                    y: 1.5
                    spacing: 6
                    Rectangle { width: 12; height: 2; color: chrome.boneA(0.30 * (1 - pulse.tt)) }
                    Rectangle { width: 3; height: 2; color: chrome.boneA(0.40 * (1 - pulse.tt)) }
                    Rectangle { width: 12; height: 2; color: chrome.boneA(0.50 * (1 - pulse.tt)) }
                }

                NumberAnimation {
                    id: pulseAnim
                    target: pulse; property: "t"
                    from: 0; to: 1; duration: 620; easing.type: Easing.InOutQuad
                    onStopped: pulse.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) pulseAnim.restart() }
            }
        }
    }
}
