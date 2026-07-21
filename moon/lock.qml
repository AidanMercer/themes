import QtQuick
import QtQuick.Effects
import Quickshell

// moon: bare lock. The wallpaper stays sharp while a breach-deck terminal
// drops in — big HUD corner brackets, a black-glass card blurring its slice
// of the wallpaper, chromatic time, and the passcode typed as neon blocks.
// Everything rides host.progress so unlock plays the whole thing backwards.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color neon:    pal.neon
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta
    readonly property color dim:     pal.dim
    readonly property string mono:   pal.fontMono
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    function cyanA(a) { return Qt.rgba(cyan.r, cyan.g, cyan.b, a) }
    function neonA(a) { return Qt.rgba(neon.r, neon.g, neon.b, a) }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // same glitch driver as the desktop clock: calm ~1.5px chromatic split,
    // bursts slam it wide on a re-randomised gap. Wrong password fires one too.
    property real gx: 1.5
    property bool slicing: false
    Timer {
        interval: 3400
        repeat: true
        running: root.p > 0.2
        onTriggered: {
            glitchBurst.restart()
            interval = 1800 + Math.floor(Math.random() * 4200)
        }
    }
    SequentialAnimation {
        id: glitchBurst
        PropertyAction { target: root; property: "slicing"; value: true }
        NumberAnimation { target: root; property: "gx"; to: 8; duration: 50; easing.type: Easing.OutQuad }
        PropertyAction { target: root; property: "slicing"; value: false }
        NumberAnimation { target: root; property: "gx"; to: 1.5; duration: 280; easing.type: Easing.OutQuad }
    }
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) { glitchBurst.restart(); shake.restart() } }
        function onUnlockingChanged() { if (root.host.unlocking) glitchBurst.restart() }
    }

    // wallpaper dims at the edges but stays readable and live
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.38 * root.p
    }

    // big HUD brackets sliding in from the four screen corners
    Repeater {
        model: [
            { rx: 0, ry: 0 },
            { rx: 1, ry: 0 },
            { rx: 0, ry: 1 },
            { rx: 1, ry: 1 }
        ]
        Item {
            readonly property real inset: Math.round(34 * root.ui)
            readonly property real slide: 90 * (1 - root.p)
            width: Math.round(64 * root.ui); height: width
            x: (modelData.rx === 0 ? inset - slide : root.width - width - inset + slide)
            y: (modelData.ry === 0 ? inset - slide : root.height - height - inset + slide)
            opacity: root.p
            Rectangle {
                width: parent.width; height: 3; color: root.neon
                y: modelData.ry === 0 ? 0 : parent.height - height
            }
            Rectangle {
                width: 3; height: parent.height; color: root.neon
                x: modelData.rx === 0 ? 0 : parent.width - width
            }
        }
    }

    // slow scan beam crossing the whole screen
    Rectangle {
        width: parent.width
        height: 2
        color: root.cyan
        opacity: 0.14 * root.p
        SequentialAnimation on y {
            loops: Animation.Infinite
            running: root.p > 0.2
            NumberAnimation { to: root.height; duration: 7000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0; duration: 0 }
            PauseAnimation { duration: 2400 }
        }
    }

    // ── the breach-deck card ────────────────────────────────────────────
    Item {
        id: card
        readonly property real cw: Math.round(560 * root.ui)
        readonly property real ch: Math.round(380 * root.ui)
        width: cw; height: ch
        x: Math.round((root.width - cw) / 2)
        y: Math.round((root.height - ch) / 2) - 18 * (1 - root.p)
        opacity: root.p

        ShaderEffectSource {
            id: slice
            sourceItem: root.host.backgroundItem
            sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 40
            brightness: -0.5
            saturation: -0.3
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45) }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: root.cyanA(0.35)
        }
        // card's own corner brackets, neon this time
        Repeater {
            model: [
                { rx: 0, ry: 0 }, { rx: 1, ry: 0 },
                { rx: 0, ry: 1 }, { rx: 1, ry: 1 }
            ]
            Item {
                width: 18; height: 18
                x: modelData.rx === 0 ? -1 : card.width - width + 1
                y: modelData.ry === 0 ? -1 : card.height - height + 1
                Rectangle {
                    width: parent.width; height: 2; color: root.neon
                    y: modelData.ry === 0 ? 0 : parent.height - height
                }
                Rectangle {
                    width: 2; height: parent.height; color: root.neon
                    x: modelData.rx === 0 ? 0 : parent.width - width
                }
            }
        }

        Column {
            id: deck
            anchors.centerIn: parent
            spacing: Math.round(10 * root.ui)

            // header types out as the lock engages
            Row {
                spacing: 8
                Rectangle {
                    width: 9; height: 9; color: root.magenta
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.p > 0.2
                        NumberAnimation { to: 0.15; duration: 0 }
                        PauseAnimation { duration: 620 }
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 620 }
                    }
                }
                Text {
                    readonly property string full: "SESSION LOCKED"
                    text: full.substring(0, Math.round(Math.min(1, root.p * 1.4) * full.length))
                    color: root.cyan
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(13 * root.ui)
                    font.letterSpacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // the time — same chromatic stack as the desktop clock
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeText.width
                height: timeText.height
                Text { x: root.gx; text: timeText.text; font: timeText.font; color: root.magenta; opacity: 0.9 }
                Text { x: -root.gx; text: timeText.text; font: timeText.font; color: root.cyan; opacity: 0.9 }
                Text {
                    id: timeText
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.neon
                    font.family: root.mono
                    font.weight: Font.Black
                    font.pixelSize: Math.round(96 * root.ui)
                    font.letterSpacing: 2
                }
                Item {
                    x: 12
                    y: timeText.height * 0.42
                    width: timeText.width
                    height: timeText.height * 0.16
                    clip: true
                    visible: root.slicing
                    Text { y: -timeText.height * 0.42; text: timeText.text; font: timeText.font; color: root.cyan }
                }
                Text {
                    anchors.left: parent.right
                    anchors.leftMargin: 6
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    text: Qt.formatDateTime(clock.date, "ss")
                    color: root.magenta
                    font.family: root.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(20 * root.ui)
                }
            }

            // divider with the roaming notch
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeText.width
                height: 3
                Rectangle { anchors.fill: parent; color: root.dim }
                Rectangle {
                    width: 46; height: 3; color: root.neon
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: root.p > 0.2
                        NumberAnimation { to: timeText.width - 46; duration: 3200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 3200; easing.type: Easing.InOutSine }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd  dd.MM.yyyy").toUpperCase()
                color: root.cyan
                font.family: root.mono
                font.pixelSize: Math.round(15 * root.ui)
                font.letterSpacing: 7
            }

            Item { width: 1; height: Math.round(8 * root.ui) }

            // ── passcode: typed chars land as neon blocks ───────────────
            Item {
                id: passArea
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.cw
                height: Math.round(26 * root.ui)

                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    opacity: root.host.pwLength > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Repeater {
                        model: Math.max(root.host.pwLength, 1)
                        Rectangle {
                            width: Math.round(10 * root.ui)
                            height: Math.round(16 * root.ui)
                            color: root.host.failed ? root.magenta : root.neon
                            opacity: index < root.host.pwLength ? 1 : 0
                            scale: root.host.busy ? 0.7 : 1
                            Behavior on scale { NumberAnimation { duration: 200 } }
                        }
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    opacity: root.host.pwLength === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Text {
                        text: root.host.busy ? "// CHECKING"
                            : root.host.failed ? "// ACCESS DENIED" : "// ENTER PASSCODE"
                        color: root.host.failed ? root.magenta : root.dim
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(13 * root.ui)
                        font.letterSpacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 8; height: 13
                        color: root.host.failed ? root.magenta : root.neon
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.p > 0.2
                            NumberAnimation { to: 0; duration: 0 }
                            PauseAnimation { duration: 440 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 440 }
                        }
                    }
                }
            }
        }

        // wrong password: the whole deck flinches
        SequentialAnimation {
            id: shake
            NumberAnimation { target: deck; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
            NumberAnimation { target: deck; property: "anchors.horizontalCenterOffset"; to: 9; duration: 50 }
            NumberAnimation { target: deck; property: "anchors.horizontalCenterOffset"; to: -5; duration: 50 }
            NumberAnimation { target: deck; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
        }

        // CRT scanlines over the card
        Canvas {
            anchors.fill: parent
            opacity: 0.16
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#000000"
                ctx.lineWidth = 1
                for (let y = 0; y < height; y += 3) {
                    ctx.beginPath()
                    ctx.moveTo(0, y + 0.5)
                    ctx.lineTo(width, y + 0.5)
                    ctx.stroke()
                }
            }
        }
    }
}
