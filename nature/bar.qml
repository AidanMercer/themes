import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// nature — "golden hour" top bar: a slender branch.
//
// One slightly-curved twig spans the whole strip, sprouting small static
// leaves. Everything on the bar grows from it:
//   • workspaces are flower buds along the branch — empty ones are closed
//     green buds, occupied ones half-open with the app's icon as the heart,
//     the active one BLOOMS (petals unfold gold)
//   • now-playing hangs from the branch on a stem like a seed pod and sways
//     gently while music plays
//   • net + battery are two more hanging seed pods on the right
//   • the clock nestles among a pair of leaves in a warm glass pill
// Soft dark-pine glass pills keep everything legible over the bright video.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color moss:  pal.dim
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string sans:  "Noto Sans"
    readonly property string mono:  pal.fontMono
    readonly property string icon:  "Symbols Nerd Font"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function leafA(a)  { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function pineA(a)  { return Qt.rgba(pine.r, pine.g, pine.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

    // boot-in: the branch grows across, then the clusters bud out of it
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1000; easing.type: Easing.OutCubic }
    readonly property real bootLate: Math.max(0, (bootT - 0.4) / 0.6)

    // branch centerline height inside the strip (44px tall)
    readonly property real branchY: height * 0.34
    function branchAt(x) {
        return branchY + Math.sin(x * 0.006 + 1.2) * 2.2 * ui + Math.sin(x * 0.0016 + 0.4) * 2.0 * ui
    }

    // ── the branch itself, growing left→right on boot ──────────────────────
    Item {
        anchors.fill: parent
        clip: true
        Item {
            width: parent.width * root.bootT
            height: parent.height
            clip: true
            Canvas {
                id: branch
                width: root.width
                height: root.height
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    // main twig
                    ctx.strokeStyle = Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.9)
                    ctx.lineWidth = 2 * root.ui
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(0, root.branchAt(0))
                    for (let x = 8; x <= width; x += 8) ctx.lineTo(x, root.branchAt(x))
                    ctx.stroke()
                    // a golden light catch along the middle third
                    ctx.strokeStyle = root.goldA(0.35)
                    ctx.lineWidth = 1 * root.ui
                    ctx.beginPath()
                    ctx.moveTo(width * 0.3, root.branchAt(width * 0.3) - 1)
                    for (let x = width * 0.3; x <= width * 0.72; x += 8)
                        ctx.lineTo(x, root.branchAt(x) - 1)
                    ctx.stroke()
                    // small leaves sprouting along the twig, alternating sides
                    for (let k = 0; k < Math.floor(width / 170); k++) {
                        const lx = 60 + k * 170 + (k % 3) * 23
                        const ly = root.branchAt(lx)
                        const up = k % 2 === 0 ? -1 : 1
                        ctx.save()
                        ctx.translate(lx, ly)
                        ctx.rotate(up * (0.7 + (k % 3) * 0.18))
                        ctx.beginPath()
                        ctx.ellipse(0, -2.6 * root.ui, 11 * root.ui, 5.2 * root.ui)
                        ctx.fillStyle = root.leafA(0.55 + (k % 2) * 0.2)
                        ctx.fill()
                        ctx.restore()
                    }
                }
                Connections {
                    target: root.pal
                    function onDimChanged()  { branch.requestPaint() }
                    function onNeonChanged() { branch.requestPaint() }
                    function onCyanChanged() { branch.requestPaint() }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
        }
    }

    // ── a reusable flower bud (Canvas five-petal, open 0..1) ────────────────
    component Bud: Canvas {
        id: bud
        property real open: 0            // 0 closed, ~0.5 half-open, 1 full bloom
        property color petalCol: root.creamA(0.95)
        property color heartCol: root.gold
        property bool drawHeart: true
        Behavior on open { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
        onOpenChanged: requestPaint()
        onPetalColChanged: requestPaint()
        onHeartColChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = width / 2
            const cy = height / 2
            if (open < 0.08) {
                // closed bud: a small teardrop on the twig
                ctx.beginPath()
                ctx.ellipse(c - width * 0.14, cy - height * 0.2, width * 0.28, height * 0.4)
                ctx.fillStyle = root.leafA(0.85)
                ctx.fill()
                return
            }
            // petals unfold: length + spread ride `open`
            const pr = width * 0.30 * open
            const pw = width * 0.24 * (0.6 + 0.4 * open)
            ctx.fillStyle = Qt.rgba(petalCol.r, petalCol.g, petalCol.b, petalCol.a)
            for (let i = 0; i < 5; i++) {
                const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                const px = c + Math.cos(a) * pr
                const py = cy + Math.sin(a) * pr
                ctx.save()
                ctx.translate(px, py)
                ctx.rotate(a + Math.PI / 2)
                ctx.beginPath()
                ctx.ellipse(-pw / 2, -pr * 0.9, pw, pr * 1.8)
                ctx.fill()
                ctx.restore()
            }
            if (drawHeart) {
                ctx.beginPath()
                ctx.arc(c, cy, width * 0.13 * (0.7 + 0.3 * open), 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(heartCol.r, heartCol.g, heartCol.b, 1)
                ctx.fill()
            }
        }
        Connections {
            target: root.pal
            function onNeonChanged() { bud.requestPaint() }
            function onCyanChanged() { bud.requestPaint() }
            function onTextChanged() { bud.requestPaint() }
        }
    }

    // ── center: workspace buds along the branch ────────────────────────────
    Item {
        id: wsCluster
        height: parent.height
        width: wsRow.width
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootLate

        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1

        // keep the .desktop database observed so heuristicLookup() works
        readonly property int _keepAlive: DesktopEntries.applications.values.length

        Component.onCompleted: Hyprland.refreshToplevels()
        Connections {
            target: Hyprland
            function onRawEvent(event) {
                switch (event.name) {
                case "openwindow":
                case "closewindow":
                case "movewindow":
                case "movewindowv2":
                case "activewindowv2":
                    Hyprland.refreshToplevels()
                }
            }
        }

        function iconForWindows(wins) {
            let best = null, bestFh = Infinity
            for (const w of wins) {
                const cls = w.lastIpcObject?.class ?? ""
                if (!cls) continue
                const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
                if (fh < bestFh) { best = w; bestFh = fh }
            }
            if (!best) return Quickshell.iconPath("application-x-executable")
            const entry = DesktopEntries.heuristicLookup(best.lastIpcObject.class)
            const name = (entry && entry.icon) ? entry.icon : best.lastIpcObject.class.toLowerCase()
            return Quickshell.iconPath(name, "application-x-executable")
        }

        Row {
            id: wsRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.branchY - root.height / 2
            spacing: Math.round(7 * root.ui)

            Repeater {
                model: wsCluster.wsCount
                delegate: Item {
                    id: slot
                    required property int index
                    readonly property int wsId: wsCluster.pageBase + index
                    readonly property bool isActive: wsCluster.activeWsId === wsId
                    readonly property var windowsHere: Hyprland.toplevels.values
                        .filter(t => (t.workspace?.id ?? -1) === wsId)
                    readonly property bool isOccupied: windowsHere.length > 0

                    width: Math.round(26 * root.ui)
                    height: Math.round(30 * root.ui)

                    Bud {
                        anchors.centerIn: parent
                        width: Math.round(24 * root.ui)
                        height: Math.round(24 * root.ui)
                        open: slot.isActive ? 1 : slot.isOccupied ? 0.45 : 0
                        petalCol: slot.isActive ? root.goldA(0.95) : root.creamA(0.55)
                        heartCol: slot.isActive ? root.rose : root.gold
                        drawHeart: !slot.isOccupied || slot.isActive
                        scale: slot.isActive ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    }

                    // occupied bud: the app icon is the flower's heart
                    IconImage {
                        anchors.centerIn: parent
                        visible: slot.isOccupied
                        width: Math.round((slot.isActive ? 12 : 14) * root.ui)
                        height: width
                        source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                        opacity: slot.isActive ? 1.0 : 0.62
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                    }
                }
            }

            // a leaf divider, then the blossom button → control popup
            Canvas {
                id: divLeaf
                width: Math.round(14 * root.ui); height: Math.round(18 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.save()
                    ctx.translate(width / 2, height / 2)
                    ctx.rotate(-0.9)
                    ctx.beginPath()
                    ctx.ellipse(-6 * root.ui, -3 * root.ui, 12 * root.ui, 6 * root.ui)
                    ctx.fillStyle = root.leafA(0.6)
                    ctx.fill()
                    ctx.restore()
                }
                Connections {
                    target: root.pal
                    function onCyanChanged() { divLeaf.requestPaint() }
                }
            }

            Item {
                width: Math.round(26 * root.ui)
                height: Math.round(30 * root.ui)
                anchors.verticalCenter: parent.verticalCenter

                Bud {
                    anchors.centerIn: parent
                    width: Math.round(22 * root.ui)
                    height: Math.round(22 * root.ui)
                    open: statusMa.containsMouse ? 1 : 0.6
                    petalCol: root.goldA(statusMa.containsMouse ? 0.95 : 0.7)
                    heartCol: root.leaf
                    rotation: statusMa.containsMouse ? 36 : 0
                    Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: statusMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
                }
            }
        }
    }

    // ── a reusable hanging seed pod: stem + glass pill ──────────────────────
    // visible content goes in `content` (laid out in a Row inside the pill);
    // Timers/Processes/MouseAreas stay plain children of the pod Item itself.
    component Pod: Item {
        id: pod
        property alias content: podRow.data
        property real swing: 0
        height: root.height
        width: podPill.width

        // stem from the branch line down to the pill
        Rectangle {
            width: 1.4 * root.ui
            y: root.branchY - 2 * root.ui
            height: podPill.y - y + 2 * root.ui
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.8)
        }
        Rectangle {
            id: podPill
            y: root.branchY + 4 * root.ui
            height: root.height - y - 3 * root.ui
            width: podRow.width + Math.round(20 * root.ui)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: height / 2
            color: root.pineA(0.58)
            border.width: 1
            border.color: root.goldA(0.25)
            transformOrigin: Item.Top
            rotation: pod.swing

            Row {
                id: podRow
                anchors.centerIn: parent
                spacing: Math.round(7 * root.ui)
            }
        }
    }

    // ── far left: now-playing pod, swaying while music plays ────────────────
    Pod {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        anchors.left: parent.left
        anchors.leftMargin: Math.round(14 * root.ui)
        opacity: root.bootLate

        SequentialAnimation on swing {
            running: media.playing
            loops: Animation.Infinite
            NumberAnimation { to: 1.4; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { to: -1.4; duration: 2400; easing.type: Easing.InOutSine }
        }
        onPlayingChanged: if (!playing) swing = 0

        content: [
            Bud {
                width: Math.round(15 * root.ui); height: Math.round(15 * root.ui)
                anchors.verticalCenter: parent.verticalCenter
                open: media.playing ? 1 : 0.4
                petalCol: root.goldA(0.9)
                heartCol: root.rose
            },
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 230 * root.ui)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + "  ·  " + a : t
                }
                color: root.creamA(0.9)
                font.family: root.serif
                font.italic: true
                font.pixelSize: Math.round(12 * root.ui)
                font.letterSpacing: 0.5
            }
        ]

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
            onWheel: (w) => {
                if (!media.active) return
                if (w.modifiers & Qt.ShiftModifier) {
                    Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                        w.angleDelta.y > 0 ? "earlier" : "later"])
                    return
                }
                if (w.angleDelta.y > 0 && media.player.canGoNext) media.player.next()
                else if (w.angleDelta.y < 0 && media.player.canGoPrevious) media.player.previous()
            }
        }
    }

    // ── right: net pod, battery pod, then the clock among leaves ────────────
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: Math.round(14 * root.ui)
        height: parent.height
        spacing: Math.round(10 * root.ui)
        opacity: root.bootLate

        // net seed pod
        Pod {
            id: netPod
            property bool online: false
            property string connName: ""
            property string connType: ""

            Timer {
                interval: 10000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: netProc.running = true
            }
            Process {
                id: netProc
                command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        const line = text.trim()
                        if (!line) { netPod.online = false; netPod.connName = ""; netPod.connType = ""; return }
                        const i = line.lastIndexOf(":")
                        netPod.connName = line.slice(0, i)
                        const t = line.slice(i + 1)
                        netPod.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                        netPod.online = true
                    }
                }
            }

            content: [
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: netPod.online
                        ? String.fromCodePoint(netPod.connType === "eth" ? 0xF059F : 0xF05A9)
                        : String.fromCodePoint(0xF092F)
                    font.family: root.icon
                    font.pixelSize: Math.round(12 * root.ui)
                    color: netPod.online ? root.leaf : root.rose
                },
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: netPod.online ? netPod.connName : "offline"
                    width: Math.min(implicitWidth, 110 * root.ui)
                    elide: Text.ElideRight
                    color: root.creamA(0.8)
                    font.family: root.sans
                    font.pixelSize: Math.round(10 * root.ui)
                }
            ]
        }

        // battery seed pod (laptops only) — a little leaf that fills
        Pod {
            id: batPod
            property int percent: -1
            property bool charging: false
            visible: percent >= 0

            Timer {
                interval: 30000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: batProc.running = true
            }
            Process {
                id: batProc
                command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        const lines = text.trim().split("\n")
                        const cap = parseInt(lines[0])
                        if (lines[0] === "" || isNaN(cap)) { batPod.percent = -1; return }
                        batPod.percent = cap
                        batPod.charging = (lines[1] || "").trim() === "Charging"
                    }
                }
            }

            // leaf gauge: a leaf outline that fills bottom-up with charge
            content: [
                Item {
                    width: Math.round(13 * root.ui)
                    height: Math.round(15 * root.ui)
                    anchors.verticalCenter: parent.verticalCenter
                    Canvas {
                        id: batLeaf
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width, h = height
                            const lvl = Math.max(0, Math.min(1, batPod.percent / 100))
                            const col = batPod.charging ? root.gold
                                : batPod.percent <= 15 ? root.rose
                                : batPod.percent <= 30 ? root.pal.amber : root.leaf
                            // leaf outline
                            ctx.beginPath()
                            ctx.moveTo(w / 2, 0)
                            ctx.quadraticCurveTo(w, h * 0.35, w / 2, h)
                            ctx.quadraticCurveTo(0, h * 0.35, w / 2, 0)
                            ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.9)
                            ctx.lineWidth = 1.2
                            ctx.stroke()
                            // fill from the stem up
                            ctx.save()
                            ctx.clip()
                            ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.75)
                            ctx.fillRect(0, h * (1 - lvl), w, h * lvl)
                            ctx.restore()
                        }
                        Connections {
                            target: batPod
                            function onPercentChanged()  { batLeaf.requestPaint() }
                            function onChargingChanged() { batLeaf.requestPaint() }
                        }
                        Connections {
                            target: root.pal
                            function onCyanChanged() { batLeaf.requestPaint() }
                            function onNeonChanged() { batLeaf.requestPaint() }
                        }
                    }
                },
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (batPod.charging ? "⌁" : "") + batPod.percent + "%"
                    color: root.creamA(0.8)
                    font.family: root.sans
                    font.pixelSize: Math.round(10 * root.ui)
                }
            ]
        }

        // the clock, nestled between two leaves
        Item {
            width: clockPill.width
            height: root.height

            Rectangle {
                id: clockPill
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.branchY - root.height / 2 + 1
                height: Math.round(24 * root.ui)
                width: clockRow.width + Math.round(22 * root.ui)
                radius: height / 2
                color: root.pineA(0.58)
                border.width: 1
                border.color: root.goldA(0.3)

                Row {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: Math.round(7 * root.ui)

                    Canvas {
                        id: clockLeafL
                        width: Math.round(11 * root.ui); height: Math.round(11 * root.ui)
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.save()
                            ctx.translate(width / 2, height / 2)
                            ctx.rotate(-0.7)
                            ctx.beginPath()
                            ctx.ellipse(-width * 0.45, -height * 0.22, width * 0.9, height * 0.44)
                            ctx.fillStyle = root.leafA(0.8)
                            ctx.fill()
                            ctx.restore()
                        }
                        Connections {
                            target: root.pal
                            function onCyanChanged() { clockLeafL.requestPaint() }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(barClock.date, "HH:mm")
                        color: root.cream
                        font.family: root.serif
                        font.pixelSize: Math.round(14 * root.ui)
                        font.letterSpacing: 1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(barClock.date, "ddd d")
                        color: root.goldA(0.85)
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: Math.round(11 * root.ui)
                    }

                    Canvas {
                        id: clockLeafR
                        width: Math.round(11 * root.ui); height: Math.round(11 * root.ui)
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.save()
                            ctx.translate(width / 2, height / 2)
                            ctx.rotate(0.7)
                            ctx.beginPath()
                            ctx.ellipse(-width * 0.45, -height * 0.22, width * 0.9, height * 0.44)
                            ctx.fillStyle = root.leafA(0.8)
                            ctx.fill()
                            ctx.restore()
                        }
                        Connections {
                            target: root.pal
                            function onCyanChanged() { clockLeafR.requestPaint() }
                        }
                    }
                }
            }
        }
    }

    SystemClock { id: barClock; precision: SystemClock.Minutes }
}
