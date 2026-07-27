import QtQuick
import QtQuick.Effects
import Quickshell
import "windows.js" as W

// nightshift: bare lock (the bareLock marker tells LockStage we own the whole
// screen). Locking doesn't black the city out — the video keeps running sharp
// behind you. What happens is that the district goes to sleep: a slab of the
// frame frosts over mid-screen, the hour stands on it as a building, and the
// passcode is a floor filling up one room at a time as you type.
//
// A wrong code throws the whole floor dark in beacon red and the block shudders
// on its foundations; the right one lights every room at once and the city
// comes back up as the lock releases.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color beacon: pal.magenta
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string sans: "Noto Sans"
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function inkA(a)    { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function hazeA(a)   { return Qt.rgba(haze.r, haze.g, haze.b, a) }
    function slateA(a)  { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a)  { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    readonly property int pwSlots: 14
    readonly property int pwLen: host.pwLength !== undefined ? host.pwLength : 0
    readonly property bool failed: host.failed === true
    readonly property bool busy: host.busy === true

    // ── the night deepens, but the city stays visible ───────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.008, 0.03, 0.062, 0.44 * root.p)
    }

    // ── the frosted slab the block stands on ────────────────────────────────
    readonly property real slabW: Math.round(620 * ui)
    readonly property real slabH: Math.round(360 * ui)

    Item {
        id: panel
        width: root.slabW
        height: root.slabH
        anchors.centerIn: parent
        opacity: root.p
        scale: 0.97 + 0.03 * root.p

        // a blurred slice of the live frame — the glass someone breathed on
        ShaderEffectSource {
            id: slice
            anchors.fill: parent
            visible: false
            live: true
            hideSource: false
            sourceItem: root.host.backgroundItem ? root.host.backgroundItem : null
            sourceRect: root.host.backgroundItem
                ? Qt.rect(panel.x, panel.y, panel.width, panel.height)
                : Qt.rect(0, 0, 1, 1)
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            visible: root.host.backgroundItem !== null && root.host.backgroundItem !== undefined
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: -0.45
            brightness: -0.30
            opacity: 0.92
        }
        Rectangle {
            anchors.fill: parent
            color: root.glassA(0.62)
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.hazeA(0.30)
        }
        // the slab's lit top edge
        Rectangle {
            width: parent.width; height: 1
            color: root.hazeA(0.18)
        }

        // shudder on a bad code — the block takes it in the foundations
        SequentialAnimation {
            id: shudder
            running: false
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -9; duration: 55 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 8; duration: 70 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -4; duration: 70 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 0; duration: 90 }
        }

        Column {
            anchors.centerIn: parent
            spacing: Math.round(24 * root.ui)

            // the hour, as the building
            Facade {
                id: hourFace
                anchors.horizontalCenter: parent.horizontalCenter
                cols: W.textWidth("00:00", 1)
                rows: W.glyphH()
                cell: Math.round(11 * root.ui)
                gap: Math.round(3 * root.ui)
                lit: root.sodium
                dark: root.slate
                // lighter than the desktop clock's facade: this one sits on a
                // frosted slab, so the unlit rooms need to recede further for
                // the hour to carry across a room
                darkAlpha: 0.22
                spread: 520
                occluded: false          // the lock IS the visible surface here
                plan: {
                    const c = W.textWidth("00:00", 1)
                    const p = W.blank(c, W.glyphH())
                    W.planText(p, c, W.glyphH(), root.hhmm, 0, 0, 1)
                    return p
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: hourFace.width
                height: 1
                color: root.slateA(0.95)
            }

            // the passcode floor — one room per keystroke, filling left to right
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: pwFloor.width
                height: pwFloor.height

                Facade {
                    id: pwFloor
                    cols: root.pwSlots
                    rows: 1
                    cell: Math.round(15 * root.ui)
                    gap: Math.round(5 * root.ui)
                    lit: root.failed ? root.beacon : root.sodium
                    dark: root.slate
                    darkAlpha: 0.34
                    flicker: root.busy
                    spread: 90                 // typing lands room by room, but fast
                    occluded: false
                    plan: {
                        const p = W.blank(root.pwSlots, 1)
                        if (root.failed) return p          // the floor goes dark
                        const n = Math.min(root.pwSlots, root.pwLen)
                        for (let i = 0; i < n; i++) p[i] = 1
                        return p
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.failed ? "wrong code"
                    : root.busy ? "checking"
                    : root.pwLen > 0 ? "" : "type to unlock"
                color: root.failed ? root.beacon : root.inkA(0.7)
                font.family: root.sans
                font.pixelSize: Math.round(13 * root.ui)
                font.letterSpacing: 2.0
                height: Math.round(16 * root.ui)
            }
        }

        // the date, quiet along the slab's foot
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(14 * root.ui)
            text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
            color: root.inkA(0.62)
            font.family: root.sans
            font.pixelSize: Math.round(12 * root.ui)
            font.letterSpacing: 1.8
        }
    }

    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) shudder.restart() }
    }
}
