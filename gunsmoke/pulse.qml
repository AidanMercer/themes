import QtQuick

// gunsmoke: ledger chrome for pulse — THE RECKONING. A system monitor in a
// gunslinger's world is where the shooting happens, so this is the slot
// where the theme's laws land hardest: the fog at the foot of the window
// thickens as host.load climbs (a hot machine smokes), a re-sort riffles the
// ledger (a light powder line across the table), and killing a process IS
// the gunshot — killPulse fires the full hammer: one frame of muzzle flash
// across the window, an oxblood bloom at its heart (danger — the accent
// spent for real), and powder smoke curling up after. Chrome only; no input.
Item {
    id: chrome

    required property var pal   // snapshot palette (bone/gunmetal/oxblood/…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property string serif: "Noto Serif"
    function boneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function steelA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function ashA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function bloodA(a) { return Qt.rgba(pal.magenta.r, pal.magenta.g, pal.magenta.b, a) }

    // chassis: paper corners, bone hairline
    readonly property color cardBorder: Qt.alpha(pal.neon, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property string wordmark: "№ 1887 · THE RECKONING"

    // ── backdrop: rules, rivets, and load-smoke ─────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // double rule under the head
            Rectangle { x: 12; y: 8; width: parent.width - 24; height: 1; color: chrome.boneA(0.26) }
            Rectangle { x: 12; y: 11; width: parent.width - 24; height: 1; color: chrome.boneA(0.09) }
            // corner rivets
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3; height: 3; radius: 1.5
                    x: index % 2 === 0 ? 5 : bd.width - 8
                    y: index < 2 ? 5 : bd.height - 8
                    color: chrome.boneA(0.38)
                }
            }

            // the machine smokes: fog at the foot rides the load — thin haze
            // when idle, a thick bank when the iron runs hot
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * (0.10 + chrome.load * 0.25)
                Behavior on height { NumberAnimation { duration: 600 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 1.0
                        color: chrome.steelA(0.05 + chrome.load * 0.10)
                    }
                }
            }
            // past the redline the smoke catches light — a brass-warm warning
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.08
                opacity: Math.max(0, (chrome.load - 0.75) * 4)
                Behavior on opacity { NumberAnimation { duration: 600 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.10) }
                }
            }
        }
    }

    // ── overlay: the riffle and the gunshot ─────────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            // re-sort: a powder line riffles across the table
            Item {
                id: riffle
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                y: ov.height * 0.30
                Rectangle {
                    x: riffle.tt * ov.width - 2
                    width: 4; height: 4; radius: 2
                    color: chrome.boneA(0.9)
                }
                Rectangle {
                    x: Math.max(0, riffle.tt * ov.width - 90)
                    y: 1
                    width: Math.min(90, riffle.tt * ov.width)
                    height: 1.5
                    color: chrome.boneA(0.25 * (1 - riffle.tt * 0.6))
                }
                NumberAnimation {
                    id: riffleAnim
                    target: riffle; property: "t"
                    from: 0; to: 1; duration: 480; easing.type: Easing.InOutQuad
                    onStopped: riffle.t = -1
                }
            }

            // the kill: muzzle flash + oxblood heart + smoke after
            Rectangle {
                id: flash
                anchors.fill: parent
                color: chrome.boneA(1)
                opacity: 0
            }
            Rectangle {
                id: heart
                anchors.centerIn: parent
                width: Math.min(ov.width, ov.height) * 0.5
                height: width
                radius: width / 2
                color: "transparent"
                opacity: 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.bloodA(0.22) }
                    GradientStop { position: 0.7; color: chrome.bloodA(0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: gunshot
                // hammer: one frame of flash, the red heart with it
                ParallelAnimation {
                    PropertyAction { target: flash; property: "opacity"; value: 0.28 }
                    PropertyAction { target: heart; property: "opacity"; value: 1 }
                    PropertyAction { target: heart; property: "scale"; value: 0.6 }
                }
                PauseAnimation { duration: 60 }
                // settle: flash gone hard, the blood blooms out and thins
                ParallelAnimation {
                    NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 240; easing.type: Easing.OutQuad }
                    NumberAnimation { target: heart; property: "scale"; to: 1.5; duration: 700; easing.type: Easing.OutQuad }
                    NumberAnimation { target: heart; property: "opacity"; to: 0; duration: 700; easing.type: Easing.OutQuad }
                }
            }

            // the smoke after the shot
            Item {
                id: puff
                x: ov.width * 0.5
                y: ov.height * 0.45
                property real t: -1
                visible: t >= 0
                readonly property real tt: Math.max(0, t)
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: (index - 1.5) * 16 + Math.sin((puff.tt + index * 0.3) * 5) * 8
                        y: -puff.tt * (60 + index * 22)
                        width: (10 + index * 5) * (1 + puff.tt * 1.8)
                        height: width
                        radius: width / 2
                        color: chrome.boneA(0.12 * (1 - puff.tt))
                    }
                }
                NumberAnimation {
                    id: puffAnim
                    target: puff; property: "t"
                    from: 0; to: 1; duration: 1000; easing.type: Easing.OutQuad
                    onStopped: puff.t = -1
                }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) riffleAnim.restart() }
                function onKillPulseChanged() {
                    if (chrome.awake) { gunshot.restart(); puffAnim.restart() }
                }
            }
        }
    }
}
